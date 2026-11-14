import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';

import '../../collection/domain/collection_item.dart';

/// Spec-09 key `video_player_setting_start_from` (values by `.name`).
enum StartFrom { fromRemembered, fromBeginning, fromFixedPosition }

enum PlayerFailure { noSources, loadFailed, playbackFailed }

/// Resume point in seconds (spec-06 §6.2.3): near the end of a known length it steps back 60 s.
int startPosition(StartFrom mode, {MediaItemPosition? remembered, int fixedSeconds = 0}) {
  var start = switch (mode) {
    StartFrom.fromBeginning => 0,
    StartFrom.fromRemembered => remembered?.position ?? 0,
    StartFrom.fromFixedPosition => fixedSeconds,
  };
  final length = remembered?.length ?? 0;
  if (length > 0 && start > length - 60) start -= 60;
  return max(0, start);
}

/// Index of the source named [preferred] (`currentSourceName` = description), else the first one.
int chooseSource(List<VideoMediaItemSource> sources, String? preferred) =>
    max(0, sources.indexWhere((s) => s.description == preferred));

/// What the player is showing; playback ticks are not part of it (see `PlaybackStatus`).
final class PlayerSession {
  final String supplier;
  final String id;
  final String title;
  final List<ContentMediaItem> items;
  final int itemIndex;
  final List<VideoMediaItemSource> sources;
  final int sourceIndex;
  final bool loading;
  final PlayerFailure? failure;

  const PlayerSession({
    required this.supplier,
    required this.id,
    this.title = '',
    this.items = const [],
    this.itemIndex = 0,
    this.sources = const [],
    this.sourceIndex = 0,
    this.loading = true,
    this.failure,
  });

  ContentMediaItem? get item => itemIndex < items.length ? items[itemIndex] : null;
  VideoMediaItemSource? get source => sourceIndex < sources.length ? sources[sourceIndex] : null;
  bool get hasPrevious => itemIndex > 0;
  bool get hasNext => itemIndex + 1 < items.length;

  PlayerSession copyWith({
    String? title,
    List<ContentMediaItem>? items,
    int? itemIndex,
    List<VideoMediaItemSource>? sources,
    int? sourceIndex,
    bool? loading,
    PlayerFailure? failure,
    bool clearFailure = false,
  }) => PlayerSession(
    supplier: supplier,
    id: id,
    title: title ?? this.title,
    items: items ?? this.items,
    itemIndex: itemIndex ?? this.itemIndex,
    sources: sources ?? this.sources,
    sourceIndex: sourceIndex ?? this.sourceIndex,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
