import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:path/path.dart' as p;

import '../domain/offline_layout.dart';
import 'offline_storage.dart';

/// A source read from the offline storage (spec-08 §8.4); shown with a "downloaded" mark and preferred for playback.
abstract interface class LocalMediaSource {
  String get path;
}

final class LocalVideoSource extends VideoMediaItemSource implements LocalMediaSource {
  @override
  final String description;
  final File file;

  LocalVideoSource(this.description, this.file);

  @override
  String get path => file.path;

  @override
  Map<String, String>? get headers => null;

  @override
  ContentLanguage? get language => null;

  @override
  bool get hlsProxy => false;

  @override
  Future<Uri> get link async => Uri.file(file.path);
}

final class LocalSubtitleSource extends SubtitleMediaItemSource implements LocalMediaSource {
  @override
  final String description;
  final File file;

  LocalSubtitleSource(this.description, this.file);

  @override
  String get path => file.path;

  @override
  Map<String, String>? get headers => null;

  @override
  ContentLanguage? get language => null;

  @override
  Future<Uri> get link async => Uri.file(file.path);
}

final class LocalMangaSource extends MangaMediaItemSource implements LocalMediaSource {
  @override
  final String description;
  final Directory dir;

  LocalMangaSource(this.description, this.dir);

  @override
  String get path => dir.path;

  @override
  Map<String, String>? get headers => null;

  @override
  ContentLanguage? get language => null;

  /// Page files in name order (the downloader numbers them).
  @override
  Future<List<String>> get allPages async {
    final files = [
      for (final entity in await dir.list().toList())
        if (entity is File && !entity.path.endsWith(OfflineLayout.partSuffix)) entity.path,
    ];
    return files..sort((a, b) => p.basename(a).compareTo(p.basename(b)));
  }
}

/// Local sources of a downloaded item: videos and manga first, subtitles after.
List<ContentMediaItemSource> localSourcesOf(DownloadedItem item) => [
  for (final MapEntry(:key, :value) in item.videos.entries) LocalVideoSource(key, value),
  for (final MapEntry(:key, :value) in item.mangaPages.entries) LocalMangaSource(key, value),
  for (final MapEntry(:key, :value) in item.subtitles.entries) LocalSubtitleSource(key, value),
];

/// Online item with its downloaded sources first (spec-08 §8.4: the local source is listed first and preferred).
/// When the supplier's sources fail to load, the local ones are still offered.
final class OfflineAwareMediaItem implements ContentMediaItem {
  final ContentMediaItem remote;
  final List<ContentMediaItemSource> local;

  OfflineAwareMediaItem(this.remote, this.local);

  @override
  int get number => remote.number;

  @override
  String get title => remote.title;

  @override
  String? get section => remote.section;

  @override
  String? get image => remote.image;

  @override
  Future<List<ContentMediaItemSource>> get sources async {
    try {
      return [...local, ...await remote.sources];
    } catch (_) {
      if (local.isEmpty) rethrow;
      return local;
    }
  }
}

/// Item of downloaded content in offline mode: only local sources; [title] is set by the caller ("Episode N").
final class OfflineMediaItem implements ContentMediaItem {
  @override
  final int number;
  @override
  final String title;
  final List<ContentMediaItemSource> local;

  const OfflineMediaItem({required this.number, required this.title, required this.local});

  @override
  String? get section => null;

  @override
  String? get image => null;

  @override
  Future<List<ContentMediaItemSource>> get sources async => local;
}

/// Details of downloaded content from `details.json` (spec-08 §8.4); media items = downloaded item numbers.
final class OfflineContentDetails implements ContentDetails {
  final DownloadedContent content;
  final String Function(int number) itemTitle;

  OfflineContentDetails(this.content, {required this.itemTitle});

  @override
  String get id => content.id;

  @override
  String get supplier => content.supplier;

  @override
  String get title => content.details.title;

  @override
  String? get originalTitle => content.details.secondaryTitle;

  @override
  String get image => content.details.image;

  @override
  String get description => content.details.description;

  @override
  MediaType get mediaType => content.details.mediaType;

  @override
  List<String> get additionalInfo => content.details.additionalInfo;

  @override
  List<ContentInfo> get similar => const [];

  @override
  Future<List<ContentMediaItem>> get mediaItems async => [
    for (final item in content.items.values)
      OfflineMediaItem(number: item.number, title: itemTitle(item.number), local: localSourcesOf(item)),
  ];
}
