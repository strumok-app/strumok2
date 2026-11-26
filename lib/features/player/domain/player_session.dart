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

/// Index of the subtitles named [preferred] (`currentSubtitleName` = description); null (off) when absent.
int? chooseSubtitles(List<SubtitleMediaItemSource> subtitles, String? preferred) {
  final index = subtitles.indexWhere((s) => s.description == preferred);
  return index < 0 ? null : index;
}

/// What the player is showing; playback ticks are not part of it (see `PlaybackStatus`).
final class PlayerSession {
  final String supplier;
  final String id;
  final String title;
  final List<ContentMediaItem> items;
  final int itemIndex;
  final List<VideoMediaItemSource> sources;
  final int sourceIndex;
  final List<SubtitleMediaItemSource> subtitles;

  /// Selected supplier subtitles; null = off.
  final int? subtitleIndex;

  /// The selected supplier subtitles are being fetched and parsed.
  final bool subtitleLoading;

  /// The selected supplier subtitles could not be loaded.
  final bool subtitleFailed;

  /// Positive shows subtitles later.
  final Duration subtitleOffset;

  /// Playback rate (spec-06 §6.5).
  final double speed;
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
    this.subtitles = const [],
    this.subtitleIndex,
    this.subtitleLoading = false,
    this.subtitleFailed = false,
    this.subtitleOffset = Duration.zero,
    this.speed = 1,
    this.loading = true,
    this.failure,
  });

  ContentMediaItem? get item => itemIndex < items.length ? items[itemIndex] : null;
  VideoMediaItemSource? get source => sourceIndex < sources.length ? sources[sourceIndex] : null;
  SubtitleMediaItemSource? get subtitle => subtitleIndex == null ? null : subtitles[subtitleIndex!];
  bool get hasPrevious => itemIndex > 0;
  bool get hasNext => itemIndex + 1 < items.length;

  /// The video surface shows the current item; while loading or failed it would only show a stale frame.
  bool get showsVideo => !loading && failure == null;

  PlayerSession copyWith({
    String? title,
    List<ContentMediaItem>? items,
    int? itemIndex,
    List<VideoMediaItemSource>? sources,
    int? sourceIndex,
    List<SubtitleMediaItemSource>? subtitles,
    int? subtitleIndex,
    bool clearSubtitle = false,
    bool? subtitleLoading,
    bool? subtitleFailed,
    Duration? subtitleOffset,
    double? speed,
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
    subtitles: subtitles ?? this.subtitles,
    subtitleIndex: clearSubtitle ? null : subtitleIndex ?? this.subtitleIndex,
    subtitleLoading: subtitleLoading ?? this.subtitleLoading,
    subtitleFailed: subtitleFailed ?? this.subtitleFailed,
    subtitleOffset: subtitleOffset ?? this.subtitleOffset,
    speed: speed ?? this.speed,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
