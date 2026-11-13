import 'collection_item.dart';

/// Remote upsert (spec-03 §3.4): applied only when strictly newer; positions merged with remote winning per key.
/// Returns the item to store locally, or null to keep the local one.
CollectionItem? mergeRemoteUpsert(CollectionItem? local, CollectionItem remote) {
  if (local == null) return remote;
  if (remote.lastSeen <= local.lastSeen) return null;
  return remote.copyWith(positions: {...local.positions, ...remote.positions});
}

/// Remote removal applies when it is at least as new as the local item.
bool shouldApplyRemoteRemove(CollectionItem? local, int remoteLastSeen) =>
    local != null && remoteLastSeen >= local.lastSeen;
