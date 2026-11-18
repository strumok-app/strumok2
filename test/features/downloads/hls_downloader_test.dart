import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:strumok/core/hls/hls_aes128.dart';
import 'package:strumok/core/network/file_downloader.dart';
import 'package:strumok/core/network/http_client.dart';
import 'package:strumok/features/downloads/data/hls_downloader.dart';

import '../../helpers/ts_packets.dart';

typedef _Handler = Future<void> Function(HttpRequest request);

void main() {
  final key = Uint8List.fromList(List.generate(16, (i) => i * 7));
  final explicitIv = Uint8List.fromList(List.generate(16, (i) => 0xA0 + i));

  late HttpServer upstream;
  late Directory dir;
  late HlsDownloader downloader;
  final routes = <String, _Handler>{};
  final requests = <String>[];
  final headersSeen = <String, HttpHeaders>{};

  Uri up(String path) => Uri.parse('http://127.0.0.1:${upstream.port}$path');

  Future<void> send(HttpRequest r, List<int> body, {int status = 200}) async {
    r.response.statusCode = status;
    r.response.contentLength = body.length;
    r.response.add(body);
    await r.response.close();
  }

  _Handler text(String body) =>
      (r) => send(r, utf8.encode(body));
  _Handler bytes(List<int> body) =>
      (r) => send(r, body);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('hls_download');
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    routes.clear();
    requests.clear();
    upstream.listen((r) async {
      requests.add(r.uri.path);
      headersSeen[r.uri.path] = r.headers;
      final handler = routes[r.uri.path];
      if (handler == null) return send(r, const [], status: 404);
      await handler(r);
    });
    downloader = HlsDownloader(http.Client(), retryDelay: Duration.zero);
  });

  tearDown(() async {
    await upstream.close(force: true);
    dir.deleteSync(recursive: true);
  });

  File target() => File('${dir.path}/out.mp4');

  Future<void> download(String path, {Map<String, String>? headers, DownloadCancelToken? cancel}) =>
      downloader.download(playlistUri: up(path), target: target(), headers: headers, cancelToken: cancel);

  test('junked TS playlist → output equals the concatenation of clean packets', () async {
    final a = tsPackets(5), b = tsPackets(3), c = tsPackets(1);
    routes.addAll({
      '/v/media.m3u8': text(
        '#EXTM3U\n#EXTINF:4,\nseg1.png\n#EXTINF:4,\nseg2.jpg\n#EXTINF:4,\nseg3.png\n#EXT-X-ENDLIST\n',
      ),
      '/v/seg1.png': bytes(concatBytes([tsJunk(701), a])),
      '/v/seg2.jpg': bytes(b),
      '/v/seg3.png': bytes(concatBytes([tsJunk(17), c])),
    });
    final progress = <(int, int)>[];
    await downloader.download(
      playlistUri: up('/v/media.m3u8'),
      target: target(),
      headers: const {'referer': 'https://site.example'},
      onProgress: (done, total, _) => progress.add((done, total)),
    );

    expect(target().readAsBytesSync(), concatBytes([a, b, c]));
    expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
    expect(headersSeen['/v/seg2.jpg']!.value('referer'), 'https://site.example', reason: 'source headers');
    expect(File('${target().path}.part').existsSync(), isFalse);
    expect(File('${target().path}.part.json').existsSync(), isFalse);
  });

  test('encrypted + junked TS → decrypted and dejunked (explicit IV and media-sequence IV)', () async {
    final a = tsPackets(4), b = tsPackets(2);
    final encA = HlsAes128.encrypt(concatBytes([tsJunk(301), a]), key: key, iv: explicitIv);
    // Second segment: no IV attribute → media sequence 8 as a 16-byte big-endian IV.
    final encB = HlsAes128.encrypt(concatBytes([tsJunk(40), b]), key: key, iv: HlsAes128.sequenceIv(8));
    final ivHex = explicitIv.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    routes.addAll({
      '/e.m3u8': text(
        '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:7\n'
        '#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x$ivHex\n#EXTINF:4,\na.png\n'
        '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:4,\nb.png\n'
        '#EXT-X-KEY:METHOD=NONE\n#EXTINF:4,\nc.png\n#EXT-X-ENDLIST\n',
      ),
      '/key.bin': bytes(key),
      '/a.png': bytes(encA),
      '/b.png': bytes(encB),
      '/c.png': bytes(concatBytes([tsJunk(5), tsPackets(1)])),
    });
    await download('/e.m3u8');
    expect(target().readAsBytesSync(), concatBytes([a, b, tsPackets(1)]));
    expect(requests.where((p) => p == '/key.bin'), hasLength(1), reason: 'keys are fetched once');
  });

  test('fMP4 playlist → init once per distinct map + media, untouched', () async {
    final init1 = Uint8List.fromList(List.filled(50, 1)), init2 = Uint8List.fromList(List.filled(30, 2));
    final m = [for (var i = 0; i < 3; i++) Uint8List.fromList(List.filled(100, 0x47 + i))];
    routes.addAll({
      '/f.m3u8': text(
        '#EXTM3U\n#EXT-X-MAP:URI="init1.mp4"\n#EXTINF:4,\nm0.m4s\n#EXTINF:4,\nm1.m4s\n'
        '#EXT-X-MAP:URI="init2.mp4"\n#EXTINF:4,\nm2.m4s\n#EXT-X-ENDLIST\n',
      ),
      '/init1.mp4': bytes(init1),
      '/init2.mp4': bytes(init2),
      for (var i = 0; i < 3; i++) '/m$i.m4s': bytes(m[i]),
    });
    await download('/f.m3u8');
    expect(target().readAsBytesSync(), concatBytes([init1, m[0], m[1], init2, m[2]]));
  });

  test('byte ranges are requested with Range and dejunked', () async {
    final a = tsPackets(3), b = tsPackets(2);
    final file = concatBytes([tsJunk(10), a, tsJunk(20), b]);
    routes.addAll({
      '/r.m3u8': text(
        '#EXTM3U\n#EXT-X-BYTERANGE:${10 + a.length}@0\n#EXTINF:4,\nall.ts\n'
        '#EXT-X-BYTERANGE:${20 + b.length}\n#EXTINF:4,\nall.ts\n#EXT-X-ENDLIST\n',
      ),
      '/all.ts': (r) async {
        final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(r.headers.value('range')!)!;
        final start = int.parse(m[1]!), end = int.parse(m[2]!);
        r.response.headers.set('content-range', 'bytes $start-$end/${file.length}');
        await send(r, file.sublist(start, end + 1), status: 206);
      },
    });
    await download('/r.m3u8');
    expect(target().readAsBytesSync(), concatBytes([a, b]));
  });

  test('master playlist: highest bandwidth first, falls back to the next variant', () async {
    routes.addAll({
      '/master.m3u8': text(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nlow.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=5000000\nhigh.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=2000000\nmid.m3u8\n',
      ),
      // high.m3u8 is missing (404).
      '/mid.m3u8': text('#EXTM3U\n#EXTINF:4,\nmid.ts\n#EXT-X-ENDLIST\n'),
      '/mid.ts': bytes(tsPackets(3)),
    });
    await download('/master.m3u8');
    expect(target().readAsBytesSync(), tsPackets(3));
    expect(requests, containsAllInOrder(['/master.m3u8', '/high.m3u8', '/mid.m3u8', '/mid.ts']));
    expect(requests, isNot(contains('/low.m3u8')));
  });

  test('segments are retried 3 times on 5xx and invalid TS, then the task fails', () async {
    var calls = 0;
    routes.addAll({
      '/m.m3u8': text('#EXTM3U\n#EXTINF:4,\nflaky.png\n#EXTINF:4,\nbad.png\n#EXT-X-ENDLIST\n'),
      '/flaky.png': (r) => ++calls < 3 ? send(r, const [], status: 503) : send(r, tsPackets(2)),
      '/bad.png': bytes(List.filled(800, 0x99)),
    });
    await expectLater(download('/m.m3u8'), throwsA(isA<FormatException>()));
    expect(calls, 3);
    expect(requests.where((p) => p == '/bad.png'), hasLength(4), reason: '1 + 3 retries');
    expect(target().existsSync(), isFalse);
  });

  test('4xx is not retried', () async {
    routes['/m.m3u8'] = text('#EXTM3U\n#EXTINF:4,\ngone.png\n#EXT-X-ENDLIST\n');
    await expectLater(
      download('/m.m3u8'),
      throwsA(isA<HttpStatusException>().having((e) => e.statusCode, 'statusCode', 404)),
    );
    expect(requests.where((p) => p == '/gone.png'), hasLength(1));
  });

  test('an interrupted download continues from the next segment', () async {
    final segs = [tsPackets(2), tsPackets(3), tsPackets(4)];
    var failSecond = true;
    routes.addAll({
      '/m.m3u8': text('#EXTM3U\n#EXTINF:4,\ns0.ts\n#EXTINF:4,\ns1.ts\n#EXTINF:4,\ns2.ts\n#EXT-X-ENDLIST\n'),
      '/s0.ts': bytes(segs[0]),
      '/s1.ts': (r) => failSecond ? send(r, const [], status: 403) : send(r, segs[1]),
      '/s2.ts': bytes(segs[2]),
    });
    await expectLater(download('/m.m3u8'), throwsA(isA<HttpStatusException>()));
    expect(File('${target().path}.part').lengthSync(), segs[0].length);

    failSecond = false;
    requests.clear();
    await download('/m.m3u8');
    expect(target().readAsBytesSync(), concatBytes(segs));
    expect(requests, isNot(contains('/s0.ts')), reason: 'resumed after the first segment');
  });

  test('cancel stops between segments and keeps the partial file for resuming', () async {
    final cancel = DownloadCancelToken();
    routes.addAll({
      '/m.m3u8': text('#EXTM3U\n#EXTINF:4,\ns0.ts\n#EXTINF:4,\ns1.ts\n#EXT-X-ENDLIST\n'),
      '/s0.ts': (r) async {
        cancel.cancel();
        await send(r, tsPackets(2));
      },
      '/s1.ts': bytes(tsPackets(2)),
    });
    await expectLater(download('/m.m3u8', cancel: cancel), throwsA(isA<DownloadCanceledException>()));
    expect(requests, isNot(contains('/s1.ts')));
    expect(target().existsSync(), isFalse);
  });

  test('SAMPLE-AES is reported as unsupported without retries', () async {
    routes.addAll({
      '/m.m3u8': text('#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI="k"\n#EXTINF:4,\ns.ts\n#EXT-X-ENDLIST\n'),
      '/s.ts': bytes(tsPackets(1)),
    });
    await expectLater(download('/m.m3u8'), throwsA(isA<UnsupportedHlsException>()));
    expect(requests.where((p) => p == '/s.ts'), hasLength(1));
  });

  test('isHlsResponse: extension, content type or #EXTM3U sniffing', () {
    expect(isHlsResponse(Uri.parse('https://a/b/index.M3U8?t=1')), isTrue);
    expect(isHlsResponse(Uri.parse('https://a/b/play'), contentType: 'application/vnd.apple.mpegurl'), isTrue);
    expect(isHlsResponse(Uri.parse('https://a/b/play'), contentType: 'audio/x-mpegurl; charset=utf-8'), isTrue);
    expect(isHlsResponse(Uri.parse('https://a/b/play'), head: utf8.encode('\uFEFF\n#EXTM3U\n#EXT')), isTrue);
    expect(isHlsResponse(Uri.parse('https://a/b/video.mp4'), contentType: 'video/mp4', head: [0, 0, 0, 24]), isFalse);
    expect(isHlsResponse(Uri.parse('https://a/b/play'), head: utf8.encode('#EXT')), isFalse);
  });
}
