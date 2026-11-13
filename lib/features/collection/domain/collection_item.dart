import 'package:content_suppliers_api/content_suppliers_api.dart';

/// Legacy spelling `latter` means "watch later" (spec-03 §3.2); names are the JSON values.
enum CollectionStatus { none, latter, inProgress, complete, onHold }

enum CollectionPriority {
  low,
  normal,
  high;

  static CollectionPriority fromInt(int value) => values[value.clamp(0, values.length - 1)];
}

/// RTDB key restrictions: `/` → `|`, `.` removed, no separator (spec-03 §3.1).
String collectionItemKey(String supplier, String id) => supplier + id.replaceAll('/', '|').replaceAll('.', '');

final class MediaItemPosition {
  /// Video: seconds; manga: page index.
  final int position;

  /// Video: seconds; manga: page count; 0 when unknown.
  final int length;

  const MediaItemPosition({required this.position, this.length = 0});

  factory MediaItemPosition.fromJson(Map<Object?, Object?> json) =>
      MediaItemPosition(position: _int(json['position']) ?? 0, length: _int(json['length']) ?? 0);

  Map<String, Object?> toJson() => {'position': position, 'length': length};

  double get progress => length > 0 ? (position / length).clamp(0, 1).toDouble() : 0;

  @override
  bool operator ==(Object other) => other is MediaItemPosition && other.position == position && other.length == length;

  @override
  int get hashCode => Object.hash(position, length);
}

/// Collection entry, JSON-compatible with the legacy app and Firebase RTDB (spec-03 §3.2).
final class CollectionItem {
  final String id;
  final String supplier;
  final String title;
  final String image;
  final MediaType mediaType;
  final int currentItem;
  final String? currentSourceName;
  final String? currentSubtitleName;
  final Map<int, MediaItemPosition> positions;
  final CollectionStatus status;
  final CollectionPriority priority;

  /// Milliseconds since epoch; conflict-resolution clock.
  final int lastSeen;

  const CollectionItem({
    required this.id,
    required this.supplier,
    required this.title,
    required this.image,
    this.mediaType = MediaType.video,
    this.currentItem = 0,
    this.currentSourceName,
    this.currentSubtitleName,
    this.positions = const {},
    this.status = CollectionStatus.none,
    this.priority = CollectionPriority.normal,
    this.lastSeen = 0,
  });

  String get key => collectionItemKey(supplier, id);

  MediaItemPosition? get currentPosition => positions[currentItem];

  /// Tolerant reader: missing fields get defaults, numbers may be doubles, `positions` may be an array.
  factory CollectionItem.fromJson(Map<Object?, Object?> json) => CollectionItem(
    id: json['id'] as String,
    supplier: json['supplier'] as String,
    title: json['title'] as String? ?? '',
    image: json['image'] as String? ?? '',
    mediaType: MediaType.values.asNameMap()[json['mediaType']] ?? MediaType.video,
    currentItem: _int(json['currentItem']) ?? 0,
    currentSourceName: json['currentSourceName'] as String?,
    currentSubtitleName: json['currentSubtitleName'] as String?,
    positions: parsePositions(json['positions']),
    status: CollectionStatus.values.asNameMap()[json['status']] ?? CollectionStatus.none,
    priority: CollectionPriority.fromInt(_int(json['priority']) ?? 1),
    lastSeen: _int(json['lastSeen']) ?? 0,
  );

  /// Exactly the legacy key set; local-only fields must never be added here.
  Map<String, Object?> toJson() => {
    'id': id,
    'supplier': supplier,
    'title': title,
    'image': image,
    'mediaType': mediaType.name,
    'currentItem': currentItem,
    'currentSourceName': currentSourceName,
    'currentSubtitleName': currentSubtitleName,
    'positions': {for (final e in positions.entries) '${e.key}': e.value.toJson()},
    'status': status.name,
    'priority': priority.index,
    'lastSeen': lastSeen,
  };

  CollectionItem copyWith({
    String? title,
    String? image,
    int? currentItem,
    String? currentSourceName,
    String? currentSubtitleName,
    Map<int, MediaItemPosition>? positions,
    CollectionStatus? status,
    CollectionPriority? priority,
    int? lastSeen,
  }) => CollectionItem(
    id: id,
    supplier: supplier,
    title: title ?? this.title,
    image: image ?? this.image,
    mediaType: mediaType,
    currentItem: currentItem ?? this.currentItem,
    currentSourceName: currentSourceName ?? this.currentSourceName,
    currentSubtitleName: currentSubtitleName ?? this.currentSubtitleName,
    positions: positions ?? this.positions,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    lastSeen: lastSeen ?? this.lastSeen,
  );
}

/// RTDB coerces maps with integer-like keys into arrays with null holes; accept both.
Map<int, MediaItemPosition> parsePositions(Object? raw) => switch (raw) {
  Map() => {
    for (final e in raw.entries)
      if (e.value is Map && int.tryParse('${e.key}') != null)
        int.parse('${e.key}'): MediaItemPosition.fromJson(e.value as Map),
  },
  List() => {
    for (final (i, value) in raw.indexed)
      if (value is Map) i: MediaItemPosition.fromJson(value),
  },
  _ => const {},
};

int? _int(Object? value) => value is num ? value.toInt() : null;
