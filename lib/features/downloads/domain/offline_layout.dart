import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';

/// Names in the offline storage (spec-08 §8.3, the legacy layout):
///
/// ```text
/// <root>/<supplier>_<encode(id)>/details.json
/// <root>/<supplier>_<encode(id)>/<itemIndex>/<encode(desc)>.mp4 | .vtt | pages_<encode(desc)>/
/// ```
abstract final class OfflineLayout {
  static const detailsFile = 'details.json';

  /// Unfinished files and page folders; never listed as downloaded.
  static const partSuffix = '.part';
  static const videoExtension = '.mp4';
  static const subtitleExtension = '.vtt';
  static const pagesPrefix = 'pages_';

  static String contentDirName(String supplier, String id) => '${supplier}_${encode(id)}';

  static String videoFileName(String description) => '${encode(description)}$videoExtension';

  static String subtitleFileName(String description) => '${encode(description)}$subtitleExtension';

  static String pagesDirName(String description) => '$pagesPrefix${encode(description)}';

  /// Ordered page file name; the extension comes from the page URL (`.jpg` when it has none).
  static String pageFileName(int index, String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final match = RegExp(r'\.(jpe?g|png|webp|gif|avif|bmp)$', caseSensitive: false).firstMatch(path);
    return '${(index + 1).toString().padLeft(4, '0')}.${match?.group(1)!.toLowerCase() ?? 'jpg'}';
  }

  /// `Uri.encodeComponent` keeps `*`, which Windows does not allow in file names; decoding is unaffected.
  static String encode(String value) => Uri.encodeComponent(value).replaceAll('*', '%2A');

  static String decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  /// Supplier and id of a content folder. Supplier names may contain `_` in theory, so the longest of [suppliers]
  /// followed by `_` wins; otherwise the name is split at its first `_`.
  static (String supplier, String id)? parseContentDirName(String name, {Iterable<String> suppliers = const []}) {
    final known = [
      for (final s in suppliers)
        if (name.length > s.length + 1 && name.startsWith('${s}_')) s,
    ]..sort((a, b) => b.length.compareTo(a.length));
    final supplier = known.firstOrNull ?? _beforeFirstUnderscore(name);
    if (supplier == null) return null;
    final id = name.substring(supplier.length + 1);
    return id.isEmpty ? null : (supplier, decode(id));
  }

  static String? _beforeFirstUnderscore(String name) {
    final i = name.indexOf('_');
    return i <= 0 ? null : name.substring(0, i);
  }
}

/// `details.json` of downloaded content (spec-08 §8.3).
@immutable
final class OfflineDetails {
  final String title;
  final String? secondaryTitle;
  final String image;
  final MediaType mediaType;
  final List<String> additionalInfo;
  final String description;

  const OfflineDetails({
    required this.title,
    required this.image,
    required this.mediaType,
    this.secondaryTitle,
    this.additionalInfo = const [],
    this.description = '',
  });

  factory OfflineDetails.of(ContentDetails details) => OfflineDetails(
    title: details.title,
    secondaryTitle: details.originalTitle,
    image: details.image,
    mediaType: details.mediaType,
    additionalInfo: details.additionalInfo,
    description: details.description,
  );

  /// Tolerant: missing fields get defaults.
  factory OfflineDetails.fromJson(Map<String, Object?> json) => OfflineDetails(
    title: json['title'] as String? ?? '',
    secondaryTitle: json['secondaryTitle'] as String?,
    image: json['image'] as String? ?? '',
    mediaType: MediaType.values.asNameMap()[json['mediaType']] ?? MediaType.video,
    additionalInfo: [for (final line in json['additionalInfo'] as List? ?? const []) '$line'],
    description: json['description'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'secondaryTitle': secondaryTitle,
    'image': image,
    'mediaType': mediaType.name,
    'additionalInfo': additionalInfo,
    'description': description,
  };

  @override
  bool operator ==(Object other) =>
      other is OfflineDetails &&
      other.title == title &&
      other.secondaryTitle == secondaryTitle &&
      other.image == image &&
      other.mediaType == mediaType &&
      listEquals(other.additionalInfo, additionalInfo) &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, secondaryTitle, image, mediaType, Object.hashAll(additionalInfo), description);
}
