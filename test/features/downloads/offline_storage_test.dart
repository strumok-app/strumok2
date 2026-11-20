import 'dart:convert';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:strumok/features/downloads/data/download_engine.dart';
import 'package:strumok/features/downloads/data/download_service.dart';
import 'package:strumok/features/downloads/data/local_sources.dart';
import 'package:strumok/features/downloads/data/offline_storage.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/offline_layout.dart';
import 'package:strumok/features/downloads/presentation/downloads_providers.dart';

import '../../helpers/fake_downloads.dart';
import '../../helpers/fake_player.dart';
import '../../helpers/test_overrides.dart';

void main() {
  late Directory root;
  late OfflineStorage storage;

  const details = OfflineDetails(title: 'Show', image: 'https://img/p.jpg', mediaType: MediaType.video);

  File put(String relative, [List<int> bytes = const [1, 2, 3]]) => File(p.join(root.path, relative))
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  setUp(() {
    root = Directory.systemTemp.createTempSync('offline');
    storage = OfflineStorage(root, suppliers: () => ['alpha', 'alpha_beta']);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('lists contents with details.json and their finished items', () async {
    await storage.writeDetails('alpha', 'show/1', details);
    put('alpha_show%2F1/0/Server%201.mp4', List.filled(100, 0));
    put('alpha_show%2F1/0/UA%20subs.vtt');
    put('alpha_show%2F1/2/Server%201.mp4.part');
    put('alpha_show%2F1/3/Server%201.mp4');
    put('alpha_show%2F1/3/Server%201.mp4.part.json');
    put('alpha_beta_m%2F2/1/x.mp4');
    put('alpha_beta_m%2F2/${OfflineLayout.detailsFile}', utf8.encode(jsonEncode({'title': 'Movie'})));
    put('stray.txt');
    put('nounderscore/0/a.mp4');

    expect((await storage.contentIds()).toSet(), {
      (supplier: 'alpha', id: 'show/1'),
      (supplier: 'alpha_beta', id: 'm/2'),
    });

    final show = (await storage.content('alpha', 'show/1'))!;
    expect(show.details, details);
    expect(show.items.keys, [0, 3], reason: 'item 2 has only a partial file');
    expect(show.items[0]!.videos.keys, ['Server 1']);
    expect(show.items[0]!.subtitles.keys, ['UA subs']);
    expect(await storage.size('alpha', 'show/1'), greaterThan(100));
    expect(await storage.size('alpha', 'missing'), 0);
  });

  test('a finished download rescans only its content; a new content also the list', () async {
    final counting = _CountingStorage(root);
    final runner = FakeRunner();
    final container = ProviderContainer(
      overrides: [
        offlineStorageProvider.overrideWithValue(counting),
        downloadServiceProvider.overrideWith(
          (ref) => InProcessDownloadService.start(
            DownloadEngine(store: MemoryQueueStore(), runner: runner, progressInterval: Duration.zero),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (final id in ['a', 'b']) {
      await counting.writeDetails('alpha', id, details);
      put('alpha_$id/0/A.mp4');
    }
    container
      ..listen(offlineContentsProvider, (_, _) {})
      ..listen(offlineContentSizeProvider('alpha', 'a'), (_, _) {})
      ..listen(offlineContentSizeProvider('alpha', 'b'), (_, _) {});
    await container.read(offlineContentsProvider.future);
    await container.read(offlineContentSizeProvider('alpha', 'a').future);
    final service = await container.read(downloadServiceProvider.future);
    await container.read(downloadTasksProvider.future);
    counting.scans.clear();

    Future<List<String>> finish(String id) async {
      await service.send(EnqueueDownloads([downloadRequest(id, 1, root: root.path)]));
      put('alpha_$id/1/A.mp4');
      runner.complete('alpha_${id}_1');
      await Future<void>.delayed(Duration.zero);
      final contents = await container.read(offlineContentsProvider.future);
      await container.read(offlineContentSizeProvider('alpha', id).future);
      return [for (final c in contents) '${c.id}: ${c.items.keys.join(',')}'];
    }

    expect(await finish('a'), unorderedEquals(['a: 0,1', 'b: 0']));
    expect(counting.scans, unorderedEquals(['content a', 'size a']));

    counting.scans.clear();
    await counting.writeDetails('alpha', 'c', details);
    expect(await finish('c'), unorderedEquals(['a: 0,1', 'b: 0', 'c: 1']));
    expect(counting.scans, unorderedEquals(['ids', 'content c', 'size c']));
  });

  test('details.json is written once and kept', () async {
    await storage.writeDetails('alpha', 'x', details);
    await storage.writeDetails(
      'alpha',
      'x',
      const OfflineDetails(title: 'Other', image: '', mediaType: MediaType.video),
    );
    expect((await storage.content('alpha', 'x'))!.details.title, 'Show');
    expect(await storage.content('alpha', 'missing'), isNull);
  });

  test('deleting the last item removes the content folder', () async {
    await storage.writeDetails('alpha', 'x', details);
    put('alpha_x/0/a.mp4');
    put('alpha_x/1/a.mp4');
    await storage.deleteItem('alpha', 'x', 0);
    expect((await storage.content('alpha', 'x'))!.items.keys, [1]);
    await storage.deleteItem('alpha', 'x', 1);
    expect(Directory(p.join(root.path, 'alpha_x')).existsSync(), isFalse);

    await storage.writeDetails('alpha', 'y', details);
    put('alpha_y/0/a.mp4');
    await storage.deleteContent('alpha', 'y');
    expect(await storage.contentIds(), isEmpty);
  });

  test('local sources: videos and pages first, files as links, pages in order', () async {
    await storage.writeDetails('alpha', 'm', const OfflineDetails(title: 'M', image: '', mediaType: MediaType.manga));
    put('alpha_m/4/pages_UA/0002.png');
    put('alpha_m/4/pages_UA/0001.jpg');
    put('alpha_m/4/pages_UA/0003.png.part');
    put('alpha_m/4/Srv.mp4');
    put('alpha_m/4/subs.vtt');
    final item = (await storage.content('alpha', 'm'))!.items[4]!;
    final sources = localSourcesOf(item);
    expect(sources.map((s) => (s.runtimeType, s.description)), [
      (LocalVideoSource, 'Srv'),
      (LocalMangaSource, 'UA'),
      (LocalSubtitleSource, 'subs'),
    ]);
    expect(await (sources[0] as LocalVideoSource).link, Uri.file(p.join(root.path, 'alpha_m/4/Srv.mp4')));
    expect((await (sources[1] as LocalMangaSource).allPages).map(p.basename), ['0001.jpg', '0002.png']);
  });

  test('offline details list downloaded items with local sources', () async {
    await storage.writeDetails('alpha', 's', details);
    put('alpha_s/5/Srv.mp4');
    put('alpha_s/1/Srv.mp4');
    final offline = OfflineContentDetails((await storage.content('alpha', 's'))!, itemTitle: (n) => 'Episode ${n + 1}');
    final items = await offline.mediaItems;
    expect(items.map((i) => (i.number, i.title)), [(1, 'Episode 2'), (5, 'Episode 6')]);
    expect((await items.first.sources).single, isA<LocalVideoSource>());
    expect(offline.title, 'Show');
    expect(offline.similar, isEmpty);
  });

  test('online items list local sources first and keep them when the supplier fails', () async {
    final local = [LocalVideoSource('Srv', File('/x.mp4'))];
    final remote = FakeMediaItem(0, 'E1', sourceList: [FakeVideoSource('Srv')]);
    expect((await OfflineAwareMediaItem(remote, local).sources).map((s) => s.runtimeType), [
      LocalVideoSource,
      FakeVideoSource,
    ]);

    final failing = _FailingItem();
    expect(await OfflineAwareMediaItem(failing, local).sources, local);
    expect(OfflineAwareMediaItem(failing, const []).sources, throwsStateError);
  });
}

class _CountingStorage extends OfflineStorage {
  final scans = <String>[];

  _CountingStorage(super.root);

  @override
  Future<List<OfflineContentId>> contentIds() {
    scans.add('ids');
    return super.contentIds();
  }

  @override
  Future<DownloadedContent?> content(String supplier, String id) {
    scans.add('content $id');
    return super.content(supplier, id);
  }

  @override
  Future<int> size(String supplier, String id) {
    scans.add('size $id');
    return super.size(supplier, id);
  }
}

class _FailingItem extends FakeMediaItem {
  _FailingItem() : super(0, 'E1');

  @override
  Future<List<ContentMediaItemSource>> get sources async => throw StateError('offline');
}
