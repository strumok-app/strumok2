import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast_io.dart';

import '../../../core/platform/app_paths.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/storage/offline_mode.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../profiles/presentation/profiles_providers.dart';
import '../domain/collection_item.dart';
import '../domain/collection_query.dart';
import '../domain/merge.dart';
import 'remote_collection.dart';
import 'synced_collection_repository.dart';

part 'collection_repository.g.dart';

/// A stored item changed; [item] is null when it was removed.
typedef CollectionChange = ({String key, CollectionItem? item});

/// Collection storage for one profile (spec-03): local-only, or local mirrored to Firebase.
abstract interface class CollectionRepository {
  Stream<CollectionChange> get changes;

  Future<List<CollectionItem>> all();

  /// Sets `lastSeen = now`; `status == none` deletes instead (spec-03 §3.3).
  Future<void> save(CollectionItem item);

  Future<void> delete(String key);

  Future<void> close();
}

/// Local item with its sync flag: [pending] is true until the remote has confirmed this version.
typedef LocalCollectionEntry = ({CollectionItem item, bool pending});

/// sembast store `collection`: key = item key, value = item JSON + local-only fields (spec-03 §3.5):
/// `tokens` (title words for prefix search) and `pending` (not yet confirmed by Firebase). Local-only fields are
/// never part of [CollectionItem.toJson], so they cannot reach Firebase.
///
/// Sync bookkeeping (used by the synced repository): store `deleted` keeps tombstones (key → deletion time) for
/// items removed while detached from Firebase; store `meta` keeps the uid this collection was last synced with.
class LocalCollectionRepository implements CollectionRepository {
  final DateTime Function() clock;
  final _store = stringMapStoreFactory.store('collection');
  final _deleted = StoreRef<String, int>('deleted');
  final _meta = StoreRef<String, Object?>('meta');

  static const _pendingField = 'pending';
  static const _syncedUidKey = 'syncedUid';

  /// Synchronous so the notifier state is current as soon as `save`/`delete` complete.
  final _changes = StreamController<CollectionChange>.broadcast(sync: true);
  final Future<Database> _db;

  LocalCollectionRepository(DatabaseFactory factory, String path, {required this.clock})
    : _db = factory.openDatabase(path);

  int get _now => clock().millisecondsSinceEpoch;

  @override
  Stream<CollectionChange> get changes => _changes.stream;

  @override
  Future<List<CollectionItem>> all() async => [for (final e in await entries()) e.item];

  Future<List<LocalCollectionEntry>> entries() async {
    final records = await _store.find(await _db);
    return [
      for (final r in records) (item: CollectionItem.fromJson(r.value), pending: r.value[_pendingField] != false),
    ];
  }

  @override
  Future<void> save(CollectionItem item) => saveItem(item);

  @override
  Future<void> delete(String key) => deleteItem(key);

  /// Stores [item] with `lastSeen = now`, marked pending; returns it, or null when `status == none` deleted it.
  Future<CollectionItem?> saveItem(CollectionItem item) async {
    if (item.status == CollectionStatus.none) {
      await deleteItem(item.key);
      return null;
    }
    final saved = item.copyWith(lastSeen: _now);
    final db = await _db;
    await db.transaction((tx) async {
      await _put(tx, saved, pending: true);
      await _deleted.record(saved.key).delete(tx);
    });
    _changes.add((key: saved.key, item: saved));
    return saved;
  }

  /// Removes the item and returns the deletion time. Once the collection has been synced, a tombstone keeps the
  /// removal until Firebase confirms it (or reconciliation applies it), so it is not resurrected by remote data.
  Future<int> deleteItem(String key) async {
    final deletedAt = _now;
    final db = await _db;
    final existed = await db.transaction((tx) async {
      final record = _store.record(key);
      if (!await record.exists(tx)) return false;
      await record.delete(tx);
      if (await _meta.record(_syncedUidKey).get(tx) != null) await _deleted.record(key).put(tx, deletedAt);
      return true;
    });
    if (existed) _changes.add((key: key, item: null));
    return deletedAt;
  }

  Future<void> _put(DatabaseClient client, CollectionItem item, {required bool pending}) => _store.record(item.key).put(
    client,
    {...item.toJson(), 'tokens': searchTokens(item.title), _pendingField: pending},
  );

  /// Remote upsert (spec-03 §3.4): applied only when newer than the local item, or than a local tombstone.
  Future<void> applyRemoteUpsert(CollectionItem remote) async {
    final db = await _db;
    final applied = await db.transaction((tx) async {
      final record = await _store.record(remote.key).get(tx);
      if (record == null) {
        final deletedAt = await _deleted.record(remote.key).get(tx);
        if (deletedAt != null && remote.lastSeen <= deletedAt) return null;
      }
      final merged = mergeRemoteUpsert(record == null ? null : CollectionItem.fromJson(record), remote);
      if (merged == null) return null;
      await _put(tx, merged, pending: false);
      await _deleted.record(remote.key).delete(tx);
      return merged;
    });
    if (applied != null) _changes.add((key: applied.key, item: applied));
  }

  /// Remote removal: applied when at least as new as the local item (spec-03 §3.4). A tombstone is kept: the
  /// event may be the echo of our own pending delete, and it must still block stale upserts until confirmed.
  Future<void> applyRemoteRemove(String key, int remoteLastSeen) async {
    final db = await _db;
    final removed = await db.transaction((tx) async {
      final record = await _store.record(key).get(tx);
      final local = record == null ? null : CollectionItem.fromJson(record);
      if (!shouldApplyRemoteRemove(local, remoteLastSeen)) return false;
      await _store.record(key).delete(tx);
      return true;
    });
    if (removed) _changes.add((key: key, item: null));
  }

  /// Clears `pending` when the stored version is still the one the remote confirmed.
  Future<void> markSynced(String key, int lastSeen) async {
    final db = await _db;
    await db.transaction((tx) async {
      final record = await _store.record(key).get(tx);
      if (record == null || CollectionItem.fromJson(record).lastSeen != lastSeen) return;
      await _store.record(key).update(tx, {_pendingField: false});
    });
  }

  /// The stored version of [key], or null when it is not in the collection.
  Future<CollectionItem?> current(String key) async {
    final record = await _store.record(key).get(await _db);
    return record == null ? null : CollectionItem.fromJson(record);
  }

  Future<int?> tombstone(String key) async => _deleted.record(key).get(await _db);

  Future<Map<String, int>> tombstones() async {
    final records = await _deleted.find(await _db);
    return {for (final r in records) r.key: r.value};
  }

  /// Drops the tombstone unless a newer deletion replaced it.
  Future<void> clearTombstone(String key, int deletedAt) async {
    final db = await _db;
    await db.transaction((tx) async {
      if (await _deleted.record(key).get(tx) == deletedAt) await _deleted.record(key).delete(tx);
    });
  }

  Future<String?> syncedUid() async => await _meta.record(_syncedUidKey).get(await _db) as String?;

  /// Tombstones belong to the previous account, so they are dropped when the uid changes.
  Future<void> setSyncedUid(String uid) async {
    final db = await _db;
    await db.transaction((tx) async {
      if (await _meta.record(_syncedUidKey).get(tx) == uid) return;
      await _deleted.delete(tx);
      await _meta.record(_syncedUidKey).put(tx, uid);
    });
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await (await _db).close();
  }
}

/// Overridden in tests with an in-memory factory.
@Riverpod(keepAlive: true)
DatabaseFactory collectionDatabaseFactory(Ref ref) => databaseFactoryIo;

/// The active profile's local store; re-created when the active profile changes (spec-05 §5.3).
@Riverpod(keepAlive: true)
LocalCollectionRepository localCollectionRepository(Ref ref) {
  final dir = profileDirectory(ref.watch(appPathsProvider), ref.watch(activeProfileIdProvider));
  final repository = LocalCollectionRepository(
    ref.watch(collectionDatabaseFactoryProvider),
    p.join(dir.path, 'collection.db'),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(repository.close);
  return repository;
}

typedef RemoteCollectionConnector = Future<RemoteCollection> Function(String profileId, String uid);

/// Opens `/collection/{uid}` in the profile's Firebase app; overridden in tests.
@Riverpod(keepAlive: true)
RemoteCollectionConnector remoteCollectionConnector(Ref ref) {
  final apps = ref.watch(profileFirebaseAppsProvider);
  return (profileId, uid) async {
    if (apps == null) throw StateError('Firebase is not configured');
    return FirebaseRemoteCollection.connect(await apps.app(profileId), uid);
  };
}

/// Account the active collection syncs with: none in offline mode or when signed out (spec-03 §3.6).
@Riverpod(keepAlive: true)
String? collectionSyncUid(Ref ref) {
  if (ref.watch(offlineModeProvider)) return null;
  return ref.watch(activeAuthUserProvider).value?.uid;
}

/// Local-only, or local mirrored to Firebase for the signed-in active profile (spec-03, spec-05 §5.3).
@Riverpod(keepAlive: true)
CollectionRepository collectionRepository(Ref ref) {
  final local = ref.watch(localCollectionRepositoryProvider);
  final uid = ref.watch(collectionSyncUidProvider);
  if (uid == null) return local;
  final profileId = ref.watch(activeProfileIdProvider);
  final connect = ref.watch(remoteCollectionConnectorProvider);
  final repository = SyncedCollectionRepository(local: local, uid: uid, connect: () => connect(profileId, uid));
  ref.onDispose(repository.close);
  return repository;
}
