import 'collection_item.dart';

/// Write rules for playback/reading progress (spec-03 §3.3). Each returns the item to save, or null when
/// nothing should be persisted. `lastSeen` is set by the repository on save.

const _minVideoPosition = 10;
const _minVideoPositionDelta = 10;

/// Persists only past 10 s and when moved more than 10 s; known length is stored and clamps the position.
/// Legacy behavior: a persisted position always sets `inProgress`.
CollectionItem? updateVideoProgress(
  CollectionItem item, {
  required int itemIndex,
  required int position,
  int length = 0,
}) {
  final stored = item.positions[itemIndex];
  final newLength = length > 0 ? length : (stored?.length ?? 0);
  final clamped = newLength > 0 ? position.clamp(0, newLength - 1) : position;

  final lengthChanged = length > 0 && length != stored?.length;
  final positionChanged =
      clamped > _minVideoPosition && (stored == null || (clamped - stored.position).abs() > _minVideoPositionDelta);
  if (!lengthChanged && !positionChanged) return null;

  final next = MediaItemPosition(position: positionChanged ? clamped : (stored?.position ?? 0), length: newLength);
  return item.copyWith(positions: {...item.positions, itemIndex: next}, status: CollectionStatus.inProgress);
}

/// Persists whenever the page index changes.
CollectionItem? updateMangaProgress(
  CollectionItem item, {
  required int itemIndex,
  required int page,
  int pageCount = 0,
}) {
  final stored = item.positions[itemIndex];
  if (stored?.position == page && (pageCount == 0 || stored?.length == pageCount)) return null;
  final next = MediaItemPosition(position: page, length: pageCount > 0 ? pageCount : (stored?.length ?? 0));
  return item.copyWith(positions: {...item.positions, itemIndex: next}, status: CollectionStatus.inProgress);
}

/// `priority` only applies to items in the collection.
CollectionItem? updatePriority(CollectionItem item, CollectionPriority priority) =>
    item.status == CollectionStatus.none || item.priority == priority ? null : item.copyWith(priority: priority);
