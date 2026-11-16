import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';

import 'collection_item.dart';

/// Write rules for playback/reading progress (spec-03 §3.3). Each returns the item to save, or null when
/// nothing should be persisted. `lastSeen` is set by the repository on save.

const _minVideoPosition = 10;
const _minVideoPositionDelta = 10;
const _videoPositionSaveTail = 60;

/// Persists only past 10 s, when moved more than 10 s, and outside the final 60 s of a known length.
/// Known length is stored even when the position is not saved.
/// Legacy behavior: a persisted position always sets `inProgress`.
CollectionItem? updateVideoProgress(
  CollectionItem item, {
  required int itemIndex,
  required int position,
  int length = 0,
}) {
  final stored = item.positions[itemIndex];
  final effectiveLength = length > 0 ? length : (stored?.length ?? 0);
  final clampedPosition = effectiveLength > 0 ? position.clamp(0, effectiveLength - 1) : position;

  final shouldSaveLength = length > 0 && length != stored?.length;
  final isPastMinimumPosition = clampedPosition > _minVideoPosition;
  final isInExcludedTail = effectiveLength > 0 && effectiveLength - clampedPosition <= _videoPositionSaveTail;
  final hasMovedEnough = stored == null || (clampedPosition - stored.position).abs() > _minVideoPositionDelta;
  final shouldSavePosition = isPastMinimumPosition && !isInExcludedTail && hasMovedEnough;
  if (!shouldSaveLength && !shouldSavePosition) return null;

  final positionToSave = shouldSavePosition ? clampedPosition : (stored?.position ?? 0);
  final next = MediaItemPosition(position: positionToSave, length: effectiveLength);
  return item.copyWith(positions: {...item.positions, itemIndex: next}, status: CollectionStatus.inProgress);
}

/// Persists when the page index or provided page count changes.
CollectionItem? updateMangaProgress(
  CollectionItem item, {
  required int itemIndex,
  required int page,
  int pageCount = 0,
}) {
  final stored = item.positions[itemIndex];
  final pageChanged = stored?.position != page;
  final pageCountChanged = pageCount != 0 && pageCount != stored?.length;
  if (!pageChanged && !pageCountChanged) return null;

  final lengthToSave = pageCount > 0 ? pageCount : (stored?.length ?? 0);
  final next = MediaItemPosition(position: page, length: lengthToSave);
  return item.copyWith(positions: {...item.positions, itemIndex: next}, status: CollectionStatus.inProgress);
}

/// `priority` only applies to items in the collection.
CollectionItem? updatePriority(CollectionItem item, CollectionPriority priority) =>
    item.status == CollectionStatus.none || item.priority == priority ? null : item.copyWith(priority: priority);

/// Video tail treated as "watched" (resume rule, spec-06), capped at 10% of the length for short videos.
const _videoCompletedTail = 60;

/// Video: within the last 60 s; manga: the last page was reached. Unknown length is never completed.
bool isMediaItemCompleted(MediaType type, MediaItemPosition position) {
  final length = position.length;
  if (length <= 0) return false;
  return switch (type) {
    MediaType.video => length - position.position <= min(_videoCompletedTail, max(1, length ~/ 10)),
    MediaType.manga => position.position >= length - 1,
  };
}

/// 0..1 for progress bars; null when the length is unknown. Manga pages are 0-based, so the last page is 1.
double? mediaItemProgress(MediaType type, MediaItemPosition position) {
  if (position.length <= 0) return null;
  if (isMediaItemCompleted(type, position)) return 1;
  final done = type == MediaType.manga ? position.position + 1 : position.position;
  return (done / position.length).clamp(0, 1).toDouble();
}
