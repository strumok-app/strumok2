import 'dart:convert';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:strumok/core/network/file_downloader.dart';
import 'package:strumok/core/network/http_client.dart';
import 'package:strumok/features/downloads/data/download_resolver.dart';
import 'package:strumok/features/downloads/data/hls_downloader.dart';
import 'package:strumok/features/downloads/data/media_download_runner.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';

import '../../helpers/fake_manga.dart';
import '../../helpers/fake_player.dart';
import '../../helpers/test_overrides.dart';
import '../../helpers/ts_packets.dart';

typedef _Handler = Future<void> Function(HttpRequest request);

class FakeResolver implements DownloadResolver {
  final Future<ResolvedDownload> Function(int call) onResolve;
  var calls = 0;

  FakeResolver(this.onResolve);

  @override
  Future<ResolvedDownload> resolve(DownloadRequest request) => onResolve(++calls);
}

void main() {
  late HttpServer upstream;
  late Directory root;
  final routes = <String, _Handler>{};
  final requests = <String>[];
  final ranges = <String?>[];
  final referers = <String?>[];

  Uri up(String path) => Uri.parse('http://127.0.0.1:${upstream.port}$path');

  Future<void> send(HttpRequest r, List<int> body, {int status = 200, String? type}) async {
    r.response.statusCode = status;
    if (type != null) r.response.headers.set('content-type', type);
    r.response.contentLength = body.length;
    r.response.add(body);
    await r.response.close();
  }

  /// Serves [body] honoring `Range: bytes=N-`.
  _Handler ranged(List<int> body) => (r) async {
    final m = RegExp(r'bytes=(\d+)-').firstMatch(r.headers.value('range') ?? '');
    if (m == null) return send(r, body);
    final start = int.parse(m[1]!);
    if (start >= body.length) return send(r, const [], status: 416);
    r.response.headers.set('content-range', 'bytes $start-${body.length - 1}/${body.length}');
    await send(r, body.sublist(start), status: 206);
  };

  setUp(() async {
    root = Directory.systemTemp.createTempSync('runner');
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    routes.clear();
    requests.clear();
    ranges.clear();
    referers.clear();
    upstream.listen((r) async {
      requests.add(r.uri.path);
      ranges.add(r.headers.value('range'));
      referers.add(r.headers.value('referer'));
      final handler = routes[r.uri.path];
      if (handler == null) return send(r, const [], status: 404);
      await handler(r);
    });
  });

  tearDown(() async {
    await upstream.close(force: true);
    root.deleteSync(recursive: true);
  });

  DownloadRequest request({
    FileKind kind = FileKind.video,
    String source = 'Server 1',
    List<String>? sources,
    String? subtitle,
  }) => DownloadRequest(
    supplier: 'alpha',
    contentId: 'show/1',
    itemIndex: 2,
    title: 'Show',
    itemTitle: 'Episode 3',
    kind: kind,
    sourceNames: sources ?? [source],
    subtitleName: subtitle,
    root: root.path,
  );

  String itemDir() => p.join(root.path, 'alpha_show%2F1', '2');

  MediaDownloadRunner runner(DownloadResolver resolver) => MediaDownloadRunner(
    client: http.Client(),
    resolver: resolver,
    hls: HlsDownloader(http.Client(), retryDelay: Duration.zero),
    backoff: (_) => Duration.zero,
  );

  ResolvedVideo video(String path, {ResolvedFile? subtitle}) => ResolvedVideo(
    ResolvedFile(description: 'Server 1', link: up(path), headers: const {'referer': 'https://site.example'}),
    subtitle: subtitle,
  );

  Future<List<double>> run(DownloadResolver resolver, DownloadRequest request, [DownloadCancelToken? cancel]) async {
    final progress = <double>[];
    await runner(
      resolver,
    ).run(request, onProgress: (fraction, _) => progress.add(fraction), cancelToken: cancel ?? DownloadCancelToken());
    return progress;
  }

  test('progressive video + subtitles land in the offline layout with source headers', () async {
    final body = List.generate(5000, (i) => i % 256);
    routes['/v.mp4'] = ranged(body);
    routes['/s.vtt'] = (r) => send(r, utf8.encode('WEBVTT\n'));
    final resolver = FakeResolver(
      (_) async => video(
        '/v.mp4',
        subtitle: ResolvedFile(description: 'UA subs', link: up('/s.vtt')),
      ),
    );

    final progress = await run(resolver, request(subtitle: 'UA subs'));
    expect(File(p.join(itemDir(), 'Server%201.mp4')).readAsBytesSync(), body);
    expect(File(p.join(itemDir(), 'UA%20subs.vtt')).readAsStringSync(), 'WEBVTT\n');
    expect(referers.first, 'https://site.example');
    expect(progress.last, 1);
    expect(Directory(itemDir()).listSync().map((e) => p.basename(e.path)).toSet(), {'Server%201.mp4', 'UA%20subs.vtt'});
  });

  test('a partial file resumes with Range; a server ignoring Range starts over', () async {
    final body = List.generate(3000, (i) => (i * 3) % 256);
    routes['/v.mp4'] = ranged(body);
    final part = File(p.join(itemDir(), 'Server%201.mp4.part'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(body.sublist(0, 1200));

    await run(FakeResolver((_) async => video('/v.mp4')), request());
    expect(ranges, ['bytes=1200-']);
    expect(File(p.join(itemDir(), 'Server%201.mp4')).readAsBytesSync(), body);
    expect(part.existsSync(), isFalse);

    File(p.join(itemDir(), 'Server%201.mp4')).deleteSync();
    part.writeAsBytesSync(List.filled(700, 9));
    routes['/v.mp4'] = (r) => send(r, body);
    await run(FakeResolver((_) async => video('/v.mp4')), request());
    expect(File(p.join(itemDir(), 'Server%201.mp4')).readAsBytesSync(), body);
  });

  test('a playlist behind a non-.m3u8 link is detected by sniffing and dejunked', () async {
    final a = tsPackets(4);
    routes['/play'] = (r) =>
        send(r, utf8.encode('#EXTM3U\n#EXTINF:4,\n/seg.png\n#EXT-X-ENDLIST\n'), type: 'text/plain');
    routes['/seg.png'] = (r) => send(r, concatBytes([tsJunk(701), a]), type: 'image/png');

    await run(FakeResolver((_) async => video('/play')), request());
    expect(File(p.join(itemDir(), 'Server%201.mp4')).readAsBytesSync(), a);
  });

  test('manga pages: ordered files, parallel, resumed, folder renamed when complete', () async {
    final pages = [for (var i = 0; i < 6; i++) up('/p/$i.png').toString()];
    for (var i = 0; i < 6; i++) {
      routes['/p/$i.png'] = (r) => send(r, [i]);
    }
    final dir = p.join(itemDir(), 'pages_UA');
    File(p.join('$dir.part', '0001.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([0]);
    final resolver = FakeResolver(
      (_) async => ResolvedManga(description: 'UA', pages: pages, headers: const {'referer': 'https://m.example'}),
    );

    final progress = await run(resolver, request(kind: FileKind.manga, source: 'UA'));
    final files = Directory(dir).listSync().map((e) => p.basename(e.path)).toList()..sort();
    expect(files, ['0001.png', '0002.png', '0003.png', '0004.png', '0005.png', '0006.png']);
    expect(File(p.join(dir, '0004.png')).readAsBytesSync(), [3]);
    expect(requests, isNot(contains('/p/0.png')), reason: 'kept from the earlier attempt');
    expect(referers, everyElement('https://m.example'));
    expect(Directory('$dir.part').existsSync(), isFalse);
    expect(progress.last, 1);
  });

  test('4xx re-resolves once, then fails as unavailable', () async {
    routes['/expired.mp4'] = (r) => send(r, const [], status: 403);
    final resolver = FakeResolver((_) async => video('/expired.mp4'));
    final error = await run(resolver, request()).then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<HttpStatusException>());
    expect(classifyDownloadError(error!), DownloadFailure.unavailable);
    expect(resolver.calls, 2);
  });

  test('a fresh link after re-resolving succeeds', () async {
    routes['/old.mp4'] = (r) => send(r, const [], status: 410);
    routes['/new.mp4'] = (r) => send(r, [1, 2, 3]);
    final resolver = FakeResolver((call) async => video(call == 1 ? '/old.mp4' : '/new.mp4'));
    await run(resolver, request());
    expect(File(p.join(itemDir(), 'Server%201.mp4')).readAsBytesSync(), [1, 2, 3]);
  });

  test('network errors and 5xx are retried 3 times with backoff', () async {
    var calls = 0;
    routes['/v.mp4'] = (r) => ++calls <= 3 ? send(r, const [], status: 502) : send(r, [7]);
    await run(FakeResolver((_) async => video('/v.mp4')), request());
    expect(calls, 4);

    File(p.join(itemDir(), 'Server%201.mp4')).deleteSync();
    calls = -10;
    final error = await run(
      FakeResolver((_) async => video('/v.mp4')),
      request(),
    ).then<Object?>((_) => null, onError: (Object e) => e);
    expect(classifyDownloadError(error!), DownloadFailure.network);
  });

  test('a missing source is not retried', () async {
    final resolver = FakeResolver(
      (_) async => throw const DownloadTaskException(DownloadFailure.sourceNotFound, 'gone'),
    );
    final error = await run(resolver, request()).then<Object?>((_) => null, onError: (Object e) => e);
    expect(classifyDownloadError(error!), DownloadFailure.sourceNotFound);
    expect(resolver.calls, 1);
  });

  test('cancel stops the download and keeps the partial file', () async {
    final cancel = DownloadCancelToken();
    routes['/v.mp4'] = (r) async {
      r.response.contentLength = 100000;
      r.response.add(List.filled(1000, 1));
      await r.response.flush();
      cancel.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await r.response.close().catchError((_) {});
    };
    await expectLater(
      run(FakeResolver((_) async => video('/v.mp4')), request(), cancel),
      throwsA(isA<DownloadCanceledException>()),
    );
    expect(File(p.join(itemDir(), 'Server%201.mp4')).existsSync(), isFalse);
  });

  group('SupplierDownloadResolver', () {
    FakeSupplier supplier(List<FakeMediaItem> items) =>
        FakeSupplier('alpha', details: {'show/1': FakeDetails('alpha', 'show/1', loadItems: () async => items)});

    test('finds the item by number and the source by name', () async {
      final items = [
        FakeMediaItem(0, 'E1'),
        FakeMediaItem(
          2,
          'E3',
          sourceList: [
            FakeVideoSource('Server 0'),
            FakeVideoSource('Server 1', headers: const {'referer': 'r'}),
            FakeSubtitleSource('UA subs'),
          ],
        ),
      ];
      final resolved =
          await SupplierDownloadResolver((_) => supplier(items)).resolve(request(subtitle: 'UA subs')) as ResolvedVideo;
      expect(resolved.video.description, 'Server 1');
      expect(resolved.video.link, Uri.parse('https://cdn.example.com/Server 1.m3u8'));
      expect(resolved.video.headers, {'referer': 'r'});
      expect(resolved.subtitle!.description, 'UA subs');
    });

    test('the first preferred source the item has, else the most similar one, else not found', () async {
      Future<String> resolve(List<String> names, List<String> preferred) async {
        final items = [
          FakeMediaItem(2, 'E3', sourceList: [FakeSubtitleSource('subs'), for (final n in names) FakeVideoSource(n)]),
        ];
        final resolved = await SupplierDownloadResolver(
          (_) => supplier(items),
        ).resolve(request(sources: preferred)) as ResolvedVideo;
        return resolved.video.description;
      }

      expect(await resolve(['A', 'B', 'C'], ['X', 'C', 'B']), 'C');
      // The provider tag outweighs shared words.
      expect(await resolve(['[VidUp] Server 1', '[VidFast] Server 2'], ['[VidFast] Server 1']), '[VidFast] Server 2');
      await expectLater(
        resolve(['Other'], ['Server 1']),
        throwsA(isA<DownloadTaskException>().having((e) => e.failure, 'failure', DownloadFailure.sourceNotFound)),
      );
    });

    test('manga keeps the source of the nearest earlier downloaded chapter and never changes language', () async {
      Directory(p.join(root.path, 'alpha_show%2F1', '0', 'pages_%5Ben%5D%20Beta')).createSync(recursive: true);
      Directory(p.join(root.path, 'alpha_show%2F1', '1', 'pages_%5Ben%5D%20Gamma')).createSync(recursive: true);
      // Unfinished and later chapters do not count.
      Directory(p.join(root.path, 'alpha_show%2F1', '1', 'pages_%5Ben%5D%20Beta.part')).createSync(recursive: true);
      Directory(p.join(root.path, 'alpha_show%2F1', '3', 'pages_%5Ben%5D%20Delta')).createSync(recursive: true);

      Future<String> resolve(List<String> names) async {
        final items = [
          FakeMediaItem(
            2,
            'Ch3',
            sourceList: [
              for (final n in names) FakeMangaSource(n, pages: const ['a']),
            ],
          ),
        ];
        final resolved = await SupplierDownloadResolver(
          (_) => supplier(items),
        ).resolve(request(kind: FileKind.manga, sources: ['[en] Alpha', '[uk] Alpha'])) as ResolvedManga;
        return resolved.description;
      }

      expect(await resolve(['[en] Beta', '[en] Gamma', '[en] Delta', '[uk] Alpha']), '[uk] Alpha');
      expect(await resolve(['[en] Beta', '[en] Delta', '[en] Gamma']), '[en] Gamma');
      expect(await resolve(['[es] Alpha', '[en] Omega']), '[en] Omega');
      await expectLater(resolve(['[es] Alpha', '[ja] Alpha']), throwsA(isA<DownloadTaskException>()));
    });

    test('manga pages are loaded', () async {
      final items = [
        FakeMediaItem(
          2,
          'Ch3',
          sourceList: [
            FakeMangaSource('UA', pages: const ['a', 'b']),
          ],
        ),
      ];
      final resolved = await SupplierDownloadResolver(
        (_) => supplier(items),
      ).resolve(request(kind: FileKind.manga, source: 'UA')) as ResolvedManga;
      expect(resolved.pages, ['a', 'b']);
    });

    test('missing supplier, content, item or source are reported, not retried', () async {
      Future<DownloadFailure> failure(SupplierDownloadResolver resolver) async {
        try {
          await resolver.resolve(request());
        } catch (e) {
          return classifyDownloadError(e);
        }
        fail('expected an error');
      }

      expect(await failure(SupplierDownloadResolver((_) => null)), DownloadFailure.suppliers);
      expect(await failure(SupplierDownloadResolver((_) => FakeSupplier('alpha'))), DownloadFailure.sourceNotFound);
      expect(
        await failure(SupplierDownloadResolver((_) => supplier([FakeMediaItem(0, 'E1')]))),
        DownloadFailure.sourceNotFound,
      );
      expect(
        await failure(
          SupplierDownloadResolver(
            (_) => supplier([
              FakeMediaItem(2, 'E3', sourceList: [FakeSubtitleSource('s')]),
            ]),
          ),
        ),
        DownloadFailure.sourceNotFound,
      );
    });
  });
}
