import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/player/domain/player_session.dart';
import 'package:strumok/features/player/presentation/player_controller.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_overrides.dart';

FakeMediaItem episode(int n, {bool withSources = true}) => FakeMediaItem(
  n,
  'Episode ${n + 1}',
  sourceList: withSources
      ? [
          FakeVideoSource('A', url: 'https://a.example/$n.m3u8', hlsProxy: true, headers: const {'referer': 'r'}),
          FakeVideoSource('B', url: 'https://b.example/$n.mp4'),
        ]
      : const [],
);

void main() {
  late List<FakeVideoBackend> backends;
  late FakeVideoBackend backend;
  late ProviderContainer c;
  late PlayerController controller;

  CollectionItem? stored() => c.read(collectionItemsProvider).value?[collectionItemKey('alpha', 'm1')];

  FakeVideoBackend createBackend() {
    final created = backend = FakeVideoBackend();
    backends.add(created);
    return created;
  }

  Future<void> setUpWith(List<FakeMediaItem> items, {CollectionItem? item, double? volume}) async {
    backends = [];
    final details = FakeDetails('alpha', 'm1', title: 'Movie', loadItems: () async => items);
    final supplier = FakeSupplier('alpha', details: {'m1': details});
    c = ProviderContainer(
      overrides: await testOverrides(
        bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')),
        prefs: await createTestPreferences({AppPreferences.volume: ?volume}),
        videoBackend: createBackend,
      ),
    );
    addTearDown(c.dispose);
    // Runs first (LIFO): lets fire-and-forget progress saves finish before the database closes.
    addTearDown(pumpEventQueue);
    controller = c.read(playerControllerProvider.notifier);
    await c.read(collectionItemsProvider.future);
    if (item != null) await c.read(collectionItemsProvider.notifier).save(item);
  }

  const inCollection = CollectionItem(
    id: 'm1',
    supplier: 'alpha',
    title: 'Old title',
    image: '',
    currentItem: 1,
    currentSourceName: 'B',
    positions: {1: MediaItemPosition(position: 300, length: 3000)},
    status: CollectionStatus.inProgress,
  );

  test('resumes currentItem with its remembered position and source', () async {
    await setUpWith([episode(0), episode(1), episode(2)], item: inCollection, volume: 40);
    await controller.open('alpha', 'm1');

    final session = c.read(playerControllerProvider)!;
    expect(session.loading, isFalse);
    expect(session.title, 'Movie');
    expect(session.itemIndex, 1);
    expect(session.source!.description, 'B');
    final request = backend.opened.single;
    expect(request.link.toString(), 'https://b.example/1.mp4');
    expect(request.start, const Duration(seconds: 300));
    expect(request.languages, ['uk', 'en']);
    expect(backend.calls.first, 'volume:40');
  });

  test('explicit item wins; hlsProxy and headers reach the backend', () async {
    await setUpWith([episode(0), episode(1)]);
    await controller.open('alpha', 'm1', item: 0);

    final request = backend.opened.single;
    expect(request.link.toString(), 'https://a.example/0.m3u8');
    expect(request.hlsProxy, isTrue);
    expect(request.headers, {'referer': 'r'});
    expect(request.start, Duration.zero);
  });

  test('progress is saved past 10 s and adds the item to the collection', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    expect(stored(), isNull);

    backend.emit(position: const Duration(seconds: 5));
    await pumpEventQueue();
    expect(stored(), isNull, reason: 'not past 10 s and no length yet');

    backend.emit(position: const Duration(seconds: 120), duration: const Duration(seconds: 3000));
    await pumpEventQueue();
    expect(stored()!.positions[0], const MediaItemPosition(position: 120, length: 3000));
    expect(stored()!.status, CollectionStatus.inProgress);
    expect(stored()!.title, 'Movie');
  });

  test('end of an item plays the next one and persists currentItem', () async {
    await setUpWith([episode(0), episode(1), episode(2)], item: inCollection);
    await controller.open('alpha', 'm1');

    backend.emit(position: const Duration(seconds: 2998), duration: const Duration(seconds: 3000));
    backend.end();
    await pumpEventQueue();

    expect(c.read(playerControllerProvider)!.itemIndex, 2);
    expect(backend.opened.last.link.toString(), 'https://b.example/2.mp4');
    expect(stored()!.currentItem, 2);
    expect(stored()!.positions[1]!.position, 2998);
  });

  test('playback error shows a failure; retry resumes at the last position', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    backend.emit(position: const Duration(seconds: 700));

    backend.fail('tcp: connection reset');
    expect(c.read(playerControllerProvider)!.failure, PlayerFailure.playbackFailed);

    await controller.retry();
    expect(c.read(playerControllerProvider)!.failure, isNull);
    expect(backend.opened.last.start, const Duration(seconds: 700));
  });

  test('changing source keeps the position and persists currentSourceName', () async {
    await setUpWith([episode(0), episode(1)], item: inCollection);
    await controller.open('alpha', 'm1');
    backend.emit(position: const Duration(seconds: 420));

    await controller.selectSource(0);
    expect(backend.opened.last.link.toString(), 'https://a.example/1.m3u8');
    expect(backend.opened.last.start, const Duration(seconds: 420));
    expect(stored()!.currentSourceName, 'A');
  });

  test('an item without video sources fails with noSources', () async {
    await setUpWith([episode(0, withSources: false)]);
    await controller.open('alpha', 'm1');
    expect(c.read(playerControllerProvider)!.failure, PlayerFailure.noSources);
    expect(backends, isEmpty);
  });

  test('a newer open wins over a slower earlier one', () async {
    await setUpWith([episode(0), episode(1)]);
    final first = controller.open('alpha', 'm1', item: 0);
    final second = controller.open('alpha', 'm1', item: 1);
    await (first, second).wait;

    expect(c.read(playerControllerProvider)!.itemIndex, 1);
    expect(backend.opened.map((r) => r.link.toString()), ['https://a.example/1.m3u8']);
  });

  test('close saves progress and disposes the backend', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    backend.emit(position: const Duration(seconds: 50), duration: const Duration(seconds: 100), playing: true);
    await controller.close();
    await pumpEventQueue();

    expect(c.read(playerControllerProvider), isNull);
    expect(backend.disposed, isTrue);
    expect(stored()!.positions[0]!.position, 50);
  });

  test('volume changes are persisted', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    await controller.setVolume(130);
    expect(backend.calls.last, 'volume:100');
    expect(c.read(appPreferencesProvider).getDouble(AppPreferences.volume), 100);
  });
}
