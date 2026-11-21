import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';

/// Spec-08 §8.1 task states.
enum DownloadState {
  queued,
  started,
  completed,
  failed,
  canceled;

  bool get active => this == queued || this == started;
}

/// Why a task failed; shown to the user and used to decide retries.
enum DownloadFailure {
  /// Network error, timeout or HTTP 5xx after retries.
  network,

  /// HTTP 4xx (also after re-resolving the source once): the link is gone or forbidden.
  unavailable,

  /// The chosen source (or the item / content) no longer exists at the supplier.
  sourceNotFound,

  /// Suppliers library missing or failed to load.
  suppliers,

  /// Invalid media (e.g. no MPEG-TS sync, unsupported encryption).
  invalidMedia,

  /// Writing to the downloads folder failed.
  storage,
}

/// Content group key, the task id prefix (spec-08 §8.1).
String downloadContentKey(String supplier, String id) => '${supplier}_$id';

/// Task id (spec-08 §8.1).
String downloadTaskId(String supplier, String id, int itemIndex) => '${downloadContentKey(supplier, id)}_$itemIndex';

/// What to download: one media item of a content with the chosen source (and the subtitles to fetch alongside).
@immutable
final class DownloadRequest {
  final String supplier;
  final String contentId;

  /// Media item number (index in the supplier's list).
  final int itemIndex;

  /// Content title, for the queue and the notification.
  final String title;
  final String itemTitle;
  final String image;

  /// `video` or `manga`; subtitles are only downloaded alongside a video.
  final FileKind kind;

  /// Preferred source `description`s, highest priority first (never empty). Looked up again when the task starts
  /// (links expire); an item without any of them falls back by language.
  final List<String> sourceNames;

  /// Languages captured with the preferred names, including null for unknown languages and older queues.
  final Map<String, ContentLanguage?> sourceLanguages;

  /// Preferred subtitle descriptions, highest priority first; empty means no subtitles.
  final List<String> subtitleNames;
  final Map<String, ContentLanguage?> subtitleLanguages;

  /// Downloads folder at enqueue time; files of this task go there even if the setting changes later.
  final String root;

  const DownloadRequest({
    required this.supplier,
    required this.contentId,
    required this.itemIndex,
    required this.title,
    required this.itemTitle,
    required this.kind,
    required this.sourceNames,
    required this.root,
    this.image = '',
    this.sourceLanguages = const {},
    this.subtitleNames = const [],
    this.subtitleLanguages = const {},
  });

  String get id => downloadTaskId(supplier, contentId, itemIndex);

  String get contentKey => downloadContentKey(supplier, contentId);

  factory DownloadRequest.fromJson(Map<String, Object?> json) {
    final oldSubtitle = json['subtitleName'] as String?;
    return DownloadRequest(
      supplier: json['supplier'] as String,
      contentId: json['contentId'] as String,
      itemIndex: (json['itemIndex'] as num).toInt(),
      title: json['title'] as String? ?? '',
      itemTitle: json['itemTitle'] as String? ?? '',
      image: json['image'] as String? ?? '',
      kind: FileKind.values.asNameMap()[json['kind']] ?? FileKind.video,
      // Queues saved before several sources could be picked have a single `sourceName`.
      sourceNames: [...?(json['sourceNames'] as List?)?.cast<String>(), ?json['sourceName'] as String?],
      sourceLanguages: {
        for (final entry in (json['sourceLanguages'] as Map<String, Object?>? ?? const {}).entries)
          entry.key: ContentLanguage.values.asNameMap()[entry.value],
      },
      subtitleNames: json.containsKey('subtitleNames')
          ? (json['subtitleNames'] as List).cast<String>()
          : [?oldSubtitle],
      subtitleLanguages: json.containsKey('subtitleNames')
          ? {
              for (final entry in (json['subtitleLanguages'] as Map<String, Object?>? ?? const {}).entries)
                entry.key: ContentLanguage.values.asNameMap()[entry.value],
            }
          : {?oldSubtitle: ContentLanguage.values.asNameMap()[json['subtitleLanguage']]},
      root: json['root'] as String,
    );
  }

  Map<String, Object?> toJson() => {
    'supplier': supplier,
    'contentId': contentId,
    'itemIndex': itemIndex,
    'title': title,
    'itemTitle': itemTitle,
    'image': image,
    'kind': kind.name,
    'sourceNames': sourceNames,
    'sourceLanguages': sourceLanguages.map((name, language) => MapEntry(name, language?.name)),
    'subtitleNames': subtitleNames,
    'subtitleLanguages': subtitleLanguages.map((name, language) => MapEntry(name, language?.name)),
    'root': root,
  };

  @override
  bool operator ==(Object other) =>
      other is DownloadRequest &&
      other.supplier == supplier &&
      other.contentId == contentId &&
      other.itemIndex == itemIndex &&
      other.title == title &&
      other.itemTitle == itemTitle &&
      other.image == image &&
      other.kind == kind &&
      listEquals(other.sourceNames, sourceNames) &&
      mapEquals(other.sourceLanguages, sourceLanguages) &&
      listEquals(other.subtitleNames, subtitleNames) &&
      mapEquals(other.subtitleLanguages, subtitleLanguages) &&
      other.root == root;

  @override
  int get hashCode => Object.hash(
    supplier,
    contentId,
    itemIndex,
    title,
    itemTitle,
    image,
    kind,
    Object.hashAll(sourceNames),
    Object.hashAllUnordered(sourceLanguages.entries.map((entry) => Object.hash(entry.key, entry.value))),
    Object.hashAll(subtitleNames),
    Object.hashAllUnordered(subtitleLanguages.entries.map((entry) => Object.hash(entry.key, entry.value))),
    root,
  );
}

/// A queued, running or finished download (spec-08 §8.1).
@immutable
final class DownloadTask {
  final DownloadRequest request;

  /// Enqueue order: FIFO across content groups.
  final int sequence;
  final DownloadState state;

  /// 0..1.
  final double progress;

  /// Bytes per second while started; 0 otherwise.
  final int speed;
  final DownloadFailure? failure;

  const DownloadTask({
    required this.request,
    required this.sequence,
    this.state = DownloadState.queued,
    this.progress = 0,
    this.speed = 0,
    this.failure,
  });

  String get id => request.id;

  String get contentKey => request.contentKey;

  DownloadTask copyWith({
    DownloadState? state,
    double? progress,
    int? speed,
    DownloadFailure? failure,
    bool clearFailure = false,
  }) => DownloadTask(
    request: request,
    sequence: sequence,
    state: state ?? this.state,
    progress: progress ?? this.progress,
    speed: speed ?? this.speed,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  factory DownloadTask.fromJson(Map<String, Object?> json) => DownloadTask(
    request: DownloadRequest.fromJson((json['request'] as Map).cast<String, Object?>()),
    sequence: (json['sequence'] as num).toInt(),
    state: DownloadState.values.asNameMap()[json['state']] ?? DownloadState.queued,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    speed: (json['speed'] as num?)?.toInt() ?? 0,
    failure: DownloadFailure.values.asNameMap()[json['failure']],
  );

  Map<String, Object?> toJson() => {
    'request': request.toJson(),
    'sequence': sequence,
    'state': state.name,
    'progress': progress,
    'speed': speed,
    'failure': failure?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is DownloadTask &&
      other.request == request &&
      other.sequence == sequence &&
      other.state == state &&
      other.progress == progress &&
      other.speed == speed &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(request, sequence, state, progress, speed, failure);

  @override
  String toString() => 'DownloadTask($id, ${state.name}, ${(progress * 100).round()}%)';
}
