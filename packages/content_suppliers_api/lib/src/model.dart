enum ContentType { movie, anime, cartoon, series, manga }

enum MediaType { video, manga }

/// Languages the app supports; codes a supplier reports that are not listed here are ignored.
enum ContentLanguage { en, uk }

enum FileKind { video, subtitle, manga }

abstract interface class ContentInfo {
  String get id;
  String get supplier;
  String get title;
  String? get secondaryTitle;
  String get image;
}

abstract interface class ContentDetails {
  String get id;
  String get supplier;
  String get title;
  String? get originalTitle;
  String get image;
  String get description;
  MediaType get mediaType;
  List<String> get additionalInfo;
  List<ContentInfo> get similar;

  /// Lazily loaded (spec-02 §2.3). Position in the list is the item index used by the collection.
  Future<List<ContentMediaItem>> get mediaItems;
}

abstract interface class ContentMediaItem {
  /// 0-based index in the supplier's list; never re-sorted (spec-02 §2.3).
  int get number;
  String get title;
  String? get section;
  String? get image;

  /// Lazily loaded (spec-02 §2.3).
  Future<List<ContentMediaItemSource>> get sources;
}

sealed class ContentMediaItemSource {
  FileKind get kind;
  String get description;
  Map<String, String>? get headers;
}

abstract class FileMediaItemSource extends ContentMediaItemSource {
  Future<Uri> get link;
}

abstract class VideoMediaItemSource extends FileMediaItemSource {
  @override
  FileKind get kind => FileKind.video;

  /// Segments are disguised with junk prefixes; playback must go through the dejunking proxy (spec-12).
  bool get hlsProxy;
}

abstract class SubtitleMediaItemSource extends FileMediaItemSource {
  @override
  FileKind get kind => FileKind.subtitle;
}

abstract class MangaMediaItemSource extends ContentMediaItemSource {
  @override
  FileKind get kind => FileKind.manga;

  /// Lazily loaded (spec-02 §2.3).
  Future<List<String>> get allPages;
}
