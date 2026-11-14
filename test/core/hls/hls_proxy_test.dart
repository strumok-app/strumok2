import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:strumok/core/hls/hls_proxy.dart';

import '../../helpers/ts_packets.dart';

typedef _Handler = Future<void> Function(HttpRequest request);

void main() {
  final clean = tsPackets(10);
  final junked = concatBytes([tsJunk(701), clean]);
  final fmp4 = Uint8List.fromList(List.generate(500, (i) => i % 256));

  late HttpServer upstream;
  late HlsProxy proxy;
  late http.Client client;
  final requests = <String, HttpHeaders>{};
  final routes = <String, _Handler>{};

  Uri up(String path) => Uri.parse('http://127.0.0.1:${upstream.port}$path');

  Future<http.Response> get(String path, {Map<String, String>? headers}) =>
      client.get(Uri.parse('http://127.0.0.1:${proxy.port}$path'), headers: headers);

  String q(String path) => Uri.encodeQueryComponent(up(path).toString());

  Future<void> bytes(HttpRequest r, List<int> body, {bool chunked = false}) async {
    if (chunked) {
      for (var i = 0; i < body.length; i += 100) {
        r.response.add(body.sublist(i, i + 100 > body.length ? body.length : i + 100));
        await r.response.flush();
      }
    } else {
      r.response.contentLength = body.length;
      r.response.add(body);
    }
    await r.response.close();
  }

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    routes
      ..clear()
      ..addAll({
        '/clean.png': (r) => bytes(r, tsPackets(2)),
        '/junk.png': (r) => bytes(r, junked),
        '/junk-chunked.png': (r) => bytes(r, junked, chunked: true),
        '/nosync.png': (r) => bytes(r, List.filled(800, 0x99)),
        '/init.mp4': (r) => bytes(r, fmp4),
        '/missing': (r) async {
          r.response.statusCode = 404;
          await r.response.close();
        },
        '/ranged.ts': (r) async {
          final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(r.headers.value('range') ?? '')!;
          final start = int.parse(m[1]!), end = int.parse(m[2]!);
          r.response.statusCode = 206;
          r.response.headers.set('content-range', 'bytes $start-$end/${junked.length}');
          await bytes(r, junked.sublist(start, end + 1));
        },
        '/media.m3u8': (r) => bytes(r, utf8.encode('#EXTM3U\n#EXTINF:4,\njunk.png\n#EXT-X-ENDLIST\n')),
      });
    upstream.listen((r) async {
      requests[r.uri.path] = r.headers;
      final handler = routes[r.uri.path];
      if (handler == null) {
        r.response.statusCode = 404;
        await r.response.close();
      } else {
        await handler(r);
      }
    });
    proxy = await HlsProxy.start(http.Client());
    client = http.Client();
  });

  tearDown(() async {
    client.close();
    await proxy.close();
    await upstream.close(force: true);
    requests.clear();
  });

  test('binds to loopback on an ephemeral port', () {
    expect(proxy.port, isNot(16888));
    expect(proxy.masterUrl(up('/media.m3u8')).host, '127.0.0.1');
  });

  test('clean short TS is forwarded byte-identical with Content-Length', () async {
    final r = await get('/segment?url=${q('/clean.png')}');
    expect(r.statusCode, 200);
    expect(r.bodyBytes, tsPackets(2));
    expect(r.headers['content-length'], '${2 * 188}');
    expect(r.headers['content-type'], 'video/mp2t');
  });

  for (final path in ['/junk.png', '/junk-chunked.png']) {
    test('junk is stripped and the response is length-framed ($path)', () async {
      final r = await get('/segment?url=${q(path)}');
      expect(r.statusCode, 200);
      expect(r.bodyBytes, clean);
      expect(r.headers['content-length'], '${clean.length}');
      expect(r.headers['transfer-encoding'], isNull);
    });
  }

  test('bytes=0- on a known-length segment streams as 206 over the dejunked length', () async {
    final r = await get('/segment?url=${q('/junk.png')}', headers: {'range': 'bytes=0-'});
    expect(r.statusCode, 206);
    expect(r.bodyBytes, clean);
    expect(r.headers['content-range'], 'bytes 0-${clean.length - 1}/${clean.length}');
  });

  test('TS ranges are answered against the dejunked bytes; Range is not sent upstream', () async {
    final r = await get('/segment?url=${q('/junk.png')}', headers: {'range': 'bytes=200-399'});
    expect(r.statusCode, 206);
    expect(r.bodyBytes, clean.sublist(200, 400));
    expect(r.headers['content-range'], 'bytes 200-399/${clean.length}');
    expect(requests['/junk.png']!.value('range'), isNull);
  });

  test('playlists are rewritten, have a known length and serve local ranges', () async {
    final full = await get('/master?url=${q('/media.m3u8')}');
    expect(full.statusCode, 200);
    expect(full.headers['content-type'], startsWith('application/vnd.apple.mpegurl'));
    expect(full.headers['content-length'], '${full.bodyBytes.length}');
    expect(full.body, contains('/segment?url=${q('/junk.png')}'));

    final fromStart = await get('/stream?url=${q('/media.m3u8')}', headers: {'range': 'bytes=0-'});
    expect(fromStart.statusCode, 206);
    expect(fromStart.bodyBytes, full.bodyBytes);

    final mid = await get('/stream?url=${q('/media.m3u8')}', headers: {'range': 'bytes=1-6'});
    expect(mid.statusCode, 206);
    expect(mid.body, full.body.substring(1, 7));
    expect(mid.headers['content-range'], 'bytes 1-6/${full.bodyBytes.length}');

    final beyond = await get('/stream?url=${q('/media.m3u8')}', headers: {'range': 'bytes=100000-'});
    expect(beyond.statusCode, 416);
  });

  test('encrypted (passthrough) segments are not dejunked', () async {
    final r = await get('/segment?url=${q('/junk.png')}&passthrough=true');
    expect(r.statusCode, 200);
    expect(r.bodyBytes, junked);
    expect(r.headers['content-type'], 'video/mp2t');
  });

  test('EXT-X-BYTERANGE requests forward Range to the origin', () async {
    final r = await get('/segment?url=${q('/ranged.ts')}&passthrough=true', headers: {'range': 'bytes=10-19'});
    expect(requests['/ranged.ts']!.value('range'), 'bytes=10-19');
    expect(r.statusCode, 206);
    expect(r.bodyBytes, junked.sublist(10, 20));
    expect(r.headers['content-range'], 'bytes 10-19/${junked.length}');
    expect(r.headers['content-length'], '10');
  });

  test('fMP4 init and media pass through unchanged', () async {
    final r = await get('/segment?url=${q('/init.mp4')}&format=fmp4');
    expect(r.statusCode, 200);
    expect(r.bodyBytes, fmp4);
    expect(r.headers['content-type'], 'video/mp4');
  });

  test('forwards request headers except hop-by-hop ones', () async {
    await get(
      '/segment?url=${q('/clean.png')}',
      headers: {'referer': 'https://site.example/', 'x-custom': '1', 'proxy-authorization': 'secret'},
    );
    final seen = requests['/clean.png']!;
    expect(seen.value('referer'), 'https://site.example/');
    expect(seen.value('x-custom'), '1');
    expect(seen.value('proxy-authorization'), isNull);
    expect(seen.value('host'), '127.0.0.1:${upstream.port}');
  });

  test('errors: bad url 400, upstream status forwarded, no sync 502, unknown path 404', () async {
    expect((await get('/segment')).statusCode, 400);
    expect((await get('/segment?url=ftp%3A%2F%2Fx')).statusCode, 400);
    expect((await get('/segment?url=${q('/missing')}')).statusCode, 404);
    expect((await get('/master?url=${q('/missing')}')).statusCode, 404);
    expect((await get('/segment?url=${q('/nosync.png')}')).statusCode, 502);
    expect((await get('/other?url=${q('/clean.png')}')).statusCode, 404);
  });
}
