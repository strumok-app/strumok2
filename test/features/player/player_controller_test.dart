import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  Future<void> setUpWith(List<FakeMediaItem> items, {CollectionItem? item, double? volume, http.Client? client}) async {
    backends = [];
    final details = FakeDetails('alpha', 'm1', title: 'Movie', loadItems: () async => items);
    final supplier = FakeSupplier('alpha', details: {'m1': details});
    c = ProviderContainer(
      overrides: await testOverrides(
        bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')),
        prefs: await createTestPreferences({AppPreferences.volume: ?volume}),
        videoBackend: createBackend,
        client: client,
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
    expect(stored()!.positions[1]!.position, 300, reason: 'the final 60 s do not overwrite saved progress');
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

  test('switching items stops the previous video before opening the next one', () async {
    await setUpWith([episode(0), episode(1)]);
    await controller.open('alpha', 'm1', item: 0);
    backend.emit(position: const Duration(seconds: 120), duration: const Duration(seconds: 3000), playing: true);

    await controller.next();
    expect(backend.calls.where((c) => c == 'stop' || c.startsWith('open:')), [
      'open:https://a.example/0.m3u8@0',
      'stop',
      'open:https://a.example/1.m3u8@0',
    ]);
    expect(backends, hasLength(1), reason: 'the backend and its video surface are reused');
    expect(stored()!.positions[0], const MediaItemPosition(position: 120, length: 3000));
  });

  test('switching to an item without sources leaves the player stopped and reset', () async {
    await setUpWith([episode(0), episode(1, withSources: false)]);
    await controller.open('alpha', 'm1', item: 0);
    backend.emit(position: const Duration(seconds: 120), duration: const Duration(seconds: 3000), playing: true);

    await controller.next();
    expect(c.read(playerControllerProvider)!.failure, PlayerFailure.noSources);
    expect(backend.calls, contains('stop'));
    expect(controller.status.value.playing, isFalse);
    expect(controller.status.value.position, Duration.zero);
    await pumpEventQueue();
    expect(stored()!.positions[0]!.position, 120, reason: 'the reset is not saved as progress');
  });

  test('changing source stops the previous one first', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    backend.emit(position: const Duration(seconds: 420), playing: true);

    await controller.selectSource(1);
    expect(backend.calls.sublist(backend.calls.length - 2), ['stop', 'open:https://b.example/0.mp4@420']);
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
    backend.emit(position: const Duration(seconds: 50), duration: const Duration(seconds: 120), playing: true);
    await controller.close();
    await pumpEventQueue();

    expect(c.read(playerControllerProvider), isNull);
    expect(backend.disposed, isTrue);
    expect(stored()!.positions[0]!.position, 50);
  });

  test('close in the final 60 s preserves the saved position', () async {
    await setUpWith([episode(0), episode(1)], item: inCollection);
    await controller.open('alpha', 'm1');
    backend.emit(position: const Duration(seconds: 2940), duration: const Duration(seconds: 3000));
    await controller.close();
    await pumpEventQueue();

    expect(backend.disposed, isTrue);
    expect(stored()!.positions[1], const MediaItemPosition(position: 300, length: 3000));
  });

  test('volume changes are persisted', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    await controller.setVolume(130);
    expect(backend.calls.last, 'volume:100');
    expect(c.read(appPreferencesProvider).getDouble(AppPreferences.volume), 100);
  });

  group('subtitles', () {
    late List<http.Request> requests;

    FakeMediaItem subtitled(int n) => FakeMediaItem(
      n,
      'Episode ${n + 1}',
      sourceList: [
        FakeVideoSource('A', url: 'https://a.example/$n.m3u8'),
        FakeSubtitleSource('UA', url: 'https://subs.example/$n/ua.srt', headers: const {'referer': 'r'}),
        FakeSubtitleSource('EN', url: 'https://subs.example/$n/en.srt'),
      ],
    );

    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('broken.srt')) return http.Response('', 500);
      final lang = request.url.pathSegments.last.split('.').first;
      return http.Response.bytes(
        utf8.encode('1\n00:00:10,000 --> 00:00:12,000\n$lang ${request.url.pathSegments[0]}\n'),
        200,
      );
    });

    setUp(() => requests = []);

    test('off by default; choosing one loads it with headers and shows lines at the position', () async {
      await setUpWith([subtitled(0)], client: client);
      await controller.open('alpha', 'm1');
      expect(c.read(playerControllerProvider)!.subtitles.map((s) => s.description), ['UA', 'EN']);
      expect(c.read(playerControllerProvider)!.subtitleIndex, isNull);
      expect(requests, isEmpty);

      await controller.selectSubtitles(0);
      expect(requests.single.headers['referer'], 'r');
      expect(controller.subtitleLines.value, isEmpty);

      backend.emit(position: const Duration(seconds: 11));
      expect(controller.subtitleLines.value, ['ua 0']);

      controller.setSubtitleOffset(const Duration(seconds: 2));
      expect(controller.subtitleLines.value, isEmpty, reason: 'shown 2 s later');
      backend.emit(position: const Duration(seconds: 13));
      expect(controller.subtitleLines.value, ['ua 0']);

      await controller.selectSubtitles(null);
      expect(controller.subtitleLines.value, isEmpty);
    });

    test('the choice persists as currentSubtitleName and is restored on the next item', () async {
      await setUpWith([subtitled(0), subtitled(1)], client: client, item: inCollection.copyWith(currentItem: 0));
      await controller.open('alpha', 'm1');
      await controller.selectSubtitles(1);
      expect(stored()!.currentSubtitleName, 'EN');

      await controller.next();
      await pumpEventQueue();
      expect(c.read(playerControllerProvider)!.subtitleIndex, 1);
      expect(requests.last.url.toString(), 'https://subs.example/1/en.srt');
      backend.emit(position: const Duration(seconds: 11));
      expect(controller.subtitleLines.value, ['en 1']);

      await controller.selectSubtitles(null);
      expect(stored()!.currentSubtitleName, isNull);
    });

    test('a failed load is flagged; parsed tracks are cached per item', () async {
      await setUpWith([
        FakeMediaItem(
          0,
          'Episode 1',
          sourceList: [
            FakeVideoSource('A'),
            FakeSubtitleSource('Broken', url: 'https://subs.example/0/broken.srt'),
            FakeSubtitleSource('UA', url: 'https://subs.example/0/ua.srt'),
          ],
        ),
      ], client: client);
      await controller.open('alpha', 'm1');
      await controller.selectSubtitles(0);
      expect(c.read(playerControllerProvider)!.subtitleFailed, isTrue);

      await controller.selectSubtitles(1);
      expect(c.read(playerControllerProvider)!.subtitleFailed, isFalse);
      await controller.selectSubtitles(null);
      await controller.selectSubtitles(1);
      expect(requests.where((r) => r.url.path.endsWith('ua.srt')), hasLength(1));
    });
  });

  test('audio and video track selection go to the backend', () async {
    await setUpWith([episode(0)]);
    await controller.open('alpha', 'm1');
    await controller.selectAudioTrack('2');
    await controller.selectVideoTrack(null);
    expect(backend.calls.sublist(backend.calls.length - 2), ['audio:2', 'video:null']);
  });
}
