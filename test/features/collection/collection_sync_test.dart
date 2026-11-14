import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:strumok/features/collection/data/collection_repository.dart';
import 'package:strumok/features/collection/data/synced_collection_repository.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';

import '../../helpers/fake_auth.dart';

const legacyKeys = {
  'id',
  'supplier',
  'title',
  'image',
  'mediaType',
  'currentItem',
  'currentSourceName',
  'currentSubtitleName',
  'positions',
  'status',
  'priority',
  'lastSeen',
};

void main() {
  late int now;
  late LocalCollectionRepository local;
  final opened = <SyncedCollectionRepository>[];

  setUp(() {
    now = 1000;
    local = LocalCollectionRepository(
      newDatabaseFactoryMemory(),
      'c.db',
      clock: () => DateTime.fromMillisecondsSinceEpoch(now),
    );
  });

  tearDown(() async {
    for (final repo in opened) {
      await repo.close();
    }
    opened.clear();
    await local.close();
  });

  CollectionItem item(
    String id, {
    int lastSeen = 0,
    CollectionStatus status = CollectionStatus.latter,
    Map<int, MediaItemPosition> positions = const {},
  }) => CollectionItem(
    id: id,
    supplier: 's',
    title: 'Title $id',
    image: '',
    status: status,
    lastSeen: lastSeen,
    positions: positions,
  );

  String key(String id) => collectionItemKey('s', id);

  Future<SyncedCollectionRepository> attach(FakeRemoteCollection remote, {String uid = 'u1'}) async {
    final repo = SyncedCollectionRepository(local: local, uid: uid, connect: () async => remote);
    opened.add(repo);
    await repo.attached;
    await pumpEventQueue();
    return repo;
  }

  Future<Map<String, ({int lastSeen, bool pending})>> localState() async => {
    for (final (:item, :pending) in await local.entries()) item.key: (lastSeen: item.lastSeen, pending: pending),
  };

  test('first link pushes local items that are newer or missing; newer remote items win', () async {
    now = 100;
    await local.save(item('a'));
    now = 200;
    await local.save(item('b'));
    final remote = FakeRemoteCollection()
      ..items[key('b')] = item('b', lastSeen: 300, positions: {1: const MediaItemPosition(position: 5)})
      ..items[key('c')] = item('c', lastSeen: 50);

    await attach(remote);

    expect(remote.writes.keys, [key('a')], reason: 'b is newer remotely, c only exists remotely');
    expect(remote.writes[key('a')]!.keys.toSet(), legacyKeys, reason: 'no local-only fields reach Firebase');
    expect(await localState(), {
      key('a'): (lastSeen: 100, pending: false),
      key('b'): (lastSeen: 300, pending: false),
      key('c'): (lastSeen: 50, pending: false),
    });
    expect(await local.syncedUid(), 'u1');
  });

  test('a save stays pending until the server confirms it', () async {
    final remote = FakeRemoteCollection();
    final repo = await attach(remote);
    remote.holdAcks = true;

    now = 2000;
    await repo.save(item('x'));
    await pumpEventQueue();
    expect(remote.items[key('x')]!.lastSeen, 2000);
    expect((await localState())[key('x')]!.pending, isTrue);

    remote.releaseAcks();
    await pumpEventQueue();
    expect((await localState())[key('x')]!.pending, isFalse);
  });

  test('removing via status none reaches Firebase while attached', () async {
    final remote = FakeRemoteCollection()..items[key('a')] = item('a', lastSeen: 100);
    final repo = await attach(remote);

    now = 2000;
    await repo.save(item('a', status: CollectionStatus.none));
    await pumpEventQueue();
    expect(remote.removed, [key('a')]);
    expect(remote.items, isEmpty);
    expect(await local.all(), isEmpty);
    expect(await local.tombstones(), isEmpty, reason: 'cleared once the server confirmed');
  });

  test('a failed write is retried on the next attach', () async {
    final remote = FakeRemoteCollection();
    final repo = await attach(remote);
    remote.failWrites = true;
    now = 2000;
    await repo.save(item('x'));
    await pumpEventQueue();
    await repo.close();

    remote.failWrites = false;
    remote.writes.clear();
    await attach(remote);
    expect(remote.writes.keys, [key('x')]);
    expect((await localState())[key('x')]!.pending, isFalse);
  });

  test('realtime events follow the merge rules (spec-03 §3.4)', () async {
    final remote = FakeRemoteCollection()..items[key('a')] = item('a', lastSeen: 500);
    await attach(remote);

    remote.remoteUpsert(item('a', lastSeen: 400, status: CollectionStatus.complete));
    await pumpEventQueue();
    expect((await local.all()).single.status, CollectionStatus.latter, reason: 'older remote ignored');

    remote.remoteUpsert(item('a', lastSeen: 600, status: CollectionStatus.complete));
    await pumpEventQueue();
    expect((await local.all()).single.status, CollectionStatus.complete);

    remote.emit((item: item('a', lastSeen: 599), removed: true));
    await pumpEventQueue();
    expect(await local.all(), hasLength(1), reason: 'removal older than the local item');

    remote.remoteRemove(key('a'));
    await pumpEventQueue();
    expect(await local.all(), isEmpty);
  });

  test('positions are merged with the remote winning per key', () async {
    final remote = FakeRemoteCollection();
    final repo = await attach(remote);
    now = 1000;
    await repo.save(
      item('a', positions: {0: const MediaItemPosition(position: 10), 1: const MediaItemPosition(position: 20)}),
    );
    await pumpEventQueue();

    remote.remoteUpsert(item('a', lastSeen: 2000, positions: {1: const MediaItemPosition(position: 99)}));
    await pumpEventQueue();
    expect((await local.all()).single.positions, {
      0: const MediaItemPosition(position: 10),
      1: const MediaItemPosition(position: 99),
    });
  });

  test('deletions while detached reach Firebase unless the remote item is newer', () async {
    final remote = FakeRemoteCollection()
      ..items[key('a')] = item('a', lastSeen: 100)
      ..items[key('b')] = item('b', lastSeen: 100);
    final repo = await attach(remote);
    await repo.close();

    // Offline mode: local-only repository.
    now = 200;
    await local.delete(key('a'));
    await local.delete(key('b'));
    remote.items[key('b')] = item('b', lastSeen: 300, status: CollectionStatus.complete);

    await attach(remote);
    expect(remote.removed, [key('a')]);
    expect(remote.items.keys, [key('b')]);
    expect((await local.all()).single.status, CollectionStatus.complete, reason: 'newer remote edit wins');
    expect(await local.tombstones(), isEmpty);
  });

  test('a tombstone keeps an older remote item from being resurrected by events', () async {
    final remote = FakeRemoteCollection()..items[key('a')] = item('a', lastSeen: 100);
    final repo = await attach(remote);
    remote.holdAcks = true;
    now = 200;
    await repo.delete(key('a'));

    remote.remoteUpsert(item('a', lastSeen: 150));
    await pumpEventQueue();
    expect(await local.all(), isEmpty);
  });

  test('a confirmed item deleted on another device while detached is removed locally', () async {
    final remote = FakeRemoteCollection()..items[key('a')] = item('a', lastSeen: 100);
    final repo = await attach(remote);
    await repo.close();
    remote.items.clear();

    await attach(remote);
    expect(await local.all(), isEmpty);
    expect(remote.writes, isEmpty);
  });

  test('linking another account pushes everything and drops old tombstones', () async {
    final first = FakeRemoteCollection()..items[key('a')] = item('a', lastSeen: 100);
    final repo = await attach(first);
    await repo.close();
    now = 200;
    await local.delete(key('a'));
    await local.save(item('b'));

    final second = FakeRemoteCollection()..items[key('a')] = item('a', lastSeen: 50);
    await attach(second, uid: 'u2');
    expect(second.removed, isEmpty, reason: 'deletions before the link are not applied to another account');
    expect(second.writes.keys, [key('b')]);
    expect(await local.tombstones(), isEmpty);
    expect(await local.syncedUid(), 'u2');
  });

  test('detaching closes the remote and leaves the local store usable', () async {
    final remote = FakeRemoteCollection();
    final repo = await attach(remote);
    await repo.close();
    expect(remote.closed, isTrue);
    await local.save(item('z'));
    expect(await local.all(), hasLength(1));
  });
}
