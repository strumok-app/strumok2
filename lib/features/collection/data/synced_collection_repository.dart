import 'dart:async';

import 'package:logging/logging.dart';

import '../domain/collection_item.dart';
import 'collection_repository.dart';
import 'remote_collection.dart';

final _log = Logger('CollectionSync');

/// Local-first collection mirrored to `/collection/{uid}` (spec-03 §3.3–3.6).
///
/// The UI only reads the local store. Saves/deletes go to the local store first, then to Firebase; local items stay
/// `pending` (and deletions keep a tombstone) until the server confirms. On attach, [_reconcile] pushes local
/// changes made while detached (offline mode, app killed before the server ack, or a profile's first link), then
/// realtime events are merged with the §3.4 rules.
class SyncedCollectionRepository implements CollectionRepository {
  final LocalCollectionRepository local;
  final String uid;
  final Future<RemoteCollection> Function() connect;

  RemoteCollection? _remote;
  StreamSubscription<RemoteCollectionChange>? _subscription;
  var _closed = false;

  /// Completes when the initial reconciliation finished and realtime events are applied (or attaching failed).
  late final Future<void> attached = _attach();

  SyncedCollectionRepository({required this.local, required this.uid, required this.connect}) {
    unawaited(attached);
  }

  @override
  Stream<CollectionChange> get changes => local.changes;

  @override
  Future<List<CollectionItem>> all() => local.all();

  @override
  Future<void> save(CollectionItem item) async {
    // "Remove from collection" is a save with status none (spec-03 §3.3).
    if (item.status == CollectionStatus.none) return delete(item.key);
    final saved = await local.saveItem(item);
    if (saved == null) return;
    if (_remote case final remote?) unawaited(_push(remote, saved));
  }

  @override
  Future<void> delete(String key) async {
    final deletedAt = await local.deleteItem(key);
    if (_remote case final remote?) unawaited(_remove(remote, key, deletedAt));
  }

  Future<void> _attach() async {
    try {
      final remote = await connect();
      if (_closed) {
        await remote.close();
        return;
      }
      _remote = remote;
      await _reconcile(remote);
      if (_closed) return;
      _subscription = remote.changes().listen(
        _apply,
        onError: (Object e) => _log.warning('Collection sync stream failed', e),
      );
    } catch (e, st) {
      if (!_closed) _log.warning('Could not attach collection sync', e, st);
    }
  }

  Future<void> _reconcile(RemoteCollection remote) async {
    final remoteItems = {...await remote.fetchAll()};
    if (_closed) return;
    final firstLink = await local.syncedUid() != uid;

    if (!firstLink) {
      for (final MapEntry(key: key, value: deletedAt) in (await local.tombstones()).entries) {
        final remoteItem = remoteItems[key];
        if (remoteItem == null) {
          await local.clearTombstone(key, deletedAt);
        } else if (remoteItem.lastSeen <= deletedAt) {
          remoteItems.remove(key);
          unawaited(_remove(remote, key, deletedAt));
        }
        // A newer remote item wins; the realtime upsert replaces the tombstone.
      }
    }

    for (final (:item, :pending) in await local.entries()) {
      final remoteItem = remoteItems[item.key];
      if (firstLink || pending) {
        // Local change unknown to the remote (spec-03 §3.4: on first link push newer or missing items).
        if (remoteItem == null || remoteItem.lastSeen < item.lastSeen) {
          unawaited(_push(remote, item));
        } else if (remoteItem.lastSeen == item.lastSeen) {
          await local.markSynced(item.key, item.lastSeen);
        }
      } else if (remoteItem == null) {
        // Confirmed earlier, now gone: it was deleted on another device while this one was detached.
        await local.applyRemoteRemove(item.key, item.lastSeen);
      }
    }
    await local.setSyncedUid(uid);
  }

  Future<void> _apply(RemoteCollectionChange change) async {
    try {
      if (change.removed) {
        await local.applyRemoteRemove(change.item.key, change.item.lastSeen);
      } else {
        await local.applyRemoteUpsert(change.item);
      }
    } catch (e) {
      if (!_closed) _log.warning('Could not apply remote change ${change.item.key}', e);
    }
  }

  /// Sends [item] unless a newer local save or delete superseded it (that change syncs itself); this keeps a
  /// reconcile snapshot from overwriting a concurrent edit.
  Future<void> _push(RemoteCollection remote, CollectionItem item) async {
    try {
      if ((await local.current(item.key))?.lastSeen != item.lastSeen) return;
      await remote.set(item.key, item.toJson());
      if (!_closed) await local.markSynced(item.key, item.lastSeen);
    } catch (e) {
      if (!_closed) _log.warning('Remote save failed for ${item.key}; retried on next attach', e);
    }
  }

  /// Removes [key] remotely unless the item was saved again since this deletion.
  Future<void> _remove(RemoteCollection remote, String key, int deletedAt) async {
    try {
      if (await local.tombstone(key) != deletedAt) return;
      await remote.remove(key);
      if (!_closed) await local.clearTombstone(key, deletedAt);
    } catch (e) {
      if (!_closed) _log.warning('Remote delete failed for $key; retried on next attach', e);
    }
  }

  /// Detaches from Firebase; the local store is owned (and closed) by its own provider.
  @override
  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    await _remote?.close();
  }
}
