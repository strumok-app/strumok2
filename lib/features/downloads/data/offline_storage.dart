import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../domain/download_task.dart';
import '../domain/offline_layout.dart';

final _log = Logger('OfflineStorage');

/// Downloaded files of one media item (spec-08 §8.3); descriptions are the decoded file names.
@immutable
final class DownloadedItem {
  final int number;
  final Map<String, File> videos;
  final Map<String, File> subtitles;
  final Map<String, Directory> mangaPages;

  const DownloadedItem({
    required this.number,
    this.videos = const {},
    this.subtitles = const {},
    this.mangaPages = const {},
  });

  bool get isEmpty => videos.isEmpty && mangaPages.isEmpty;
}

@immutable
final class DownloadedContent {
  final String supplier;
  final String id;
  final OfflineDetails details;

  /// By item number, ascending; only items with a finished video or page folder.
  final Map<int, DownloadedItem> items;
  final Directory dir;
  final int sizeBytes;

  const DownloadedContent({
    required this.supplier,
    required this.id,
    required this.details,
    required this.items,
    required this.dir,
    required this.sizeBytes,
  });

  String get key => downloadContentKey(supplier, id);
}

/// Reads and edits the offline storage under [root]. Unfinished (`.part`) files are ignored; contents without
/// `details.json` are not listed.
class OfflineStorage {
  final Directory root;

  /// Installed supplier names, to split content folder names (see [OfflineLayout.parseContentDirName]).
  final Iterable<String> Function() suppliers;

  OfflineStorage(this.root, {Iterable<String> Function()? suppliers}) : suppliers = suppliers ?? (() => const []);

  Directory contentDir(String supplier, String id) =>
      Directory(p.join(root.path, OfflineLayout.contentDirName(supplier, id)));

  /// Newest first.
  Future<List<DownloadedContent>> list() async {
    if (!root.existsSync()) return const [];
    final contents = <(DownloadedContent, DateTime)>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final names = OfflineLayout.parseContentDirName(p.basename(entity.path), suppliers: suppliers());
      if (names == null) continue;
      final content = await _read(names.$1, names.$2, entity);
      if (content != null) contents.add((content, entity.statSync().modified));
    }
    contents.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (content, _) in contents) content];
  }

  Future<DownloadedContent?> content(String supplier, String id) async {
    final dir = contentDir(supplier, id);
    return dir.existsSync() ? _read(supplier, id, dir) : null;
  }

  /// Written when the first download of a content starts (spec-08 §8.3); kept when it exists.
  Future<void> writeDetails(String supplier, String id, OfflineDetails details) async {
    final file = File(p.join(contentDir(supplier, id).path, OfflineLayout.detailsFile));
    if (file.existsSync()) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(details.toJson()));
  }

  Future<void> deleteContent(String supplier, String id) async {
    final dir = contentDir(supplier, id);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Removes one item; the content folder goes too when no item is left.
  Future<void> deleteItem(String supplier, String id, int number) async {
    final dir = contentDir(supplier, id);
    final itemDir = Directory(p.join(dir.path, '$number'));
    if (itemDir.existsSync()) await itemDir.delete(recursive: true);
    if (!dir.existsSync()) return;
    final hasItems = dir.listSync().any((e) => e is Directory && int.tryParse(p.basename(e.path)) != null);
    if (!hasItems) await dir.delete(recursive: true);
  }

  Future<DownloadedContent?> _read(String supplier, String id, Directory dir) async {
    final detailsFile = File(p.join(dir.path, OfflineLayout.detailsFile));
    if (!detailsFile.existsSync()) return null;
    OfflineDetails details;
    try {
      details = OfflineDetails.fromJson(jsonDecode(await detailsFile.readAsString()) as Map<String, Object?>);
    } catch (e) {
      _log.warning('Unreadable ${detailsFile.path}', e);
      return null;
    }

    final items = <int, DownloadedItem>{};
    var size = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) size += await entity.length();
    }
    await for (final entity in dir.list()) {
      final number = int.tryParse(p.basename(entity.path));
      if (entity is! Directory || number == null) continue;
      final item = _readItem(number, entity);
      if (!item.isEmpty) items[number] = item;
    }
    final sorted = Map.fromEntries(items.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return DownloadedContent(supplier: supplier, id: id, details: details, items: sorted, dir: dir, sizeBytes: size);
  }

  DownloadedItem _readItem(int number, Directory dir) {
    final videos = <String, File>{}, subtitles = <String, File>{}, pages = <String, Directory>{};
    for (final entity in dir.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
      final name = p.basename(entity.path);
      if (name.endsWith(OfflineLayout.partSuffix)) continue;
      if (entity is File && name.endsWith(OfflineLayout.videoExtension)) {
        videos[OfflineLayout.decode(p.basenameWithoutExtension(name))] = entity;
      } else if (entity is File && name.endsWith(OfflineLayout.subtitleExtension)) {
        subtitles[OfflineLayout.decode(p.basenameWithoutExtension(name))] = entity;
      } else if (entity is Directory && name.startsWith(OfflineLayout.pagesPrefix)) {
        pages[OfflineLayout.decode(name.substring(OfflineLayout.pagesPrefix.length))] = entity;
      }
    }
    return DownloadedItem(number: number, videos: videos, subtitles: subtitles, mangaPages: pages);
  }
}
