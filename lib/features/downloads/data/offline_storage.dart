import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/download_task.dart';
import '../domain/offline_layout.dart';

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

  const DownloadedContent({
    required this.supplier,
    required this.id,
    required this.details,
    required this.items,
    required this.dir,
  });

  String get key => downloadContentKey(supplier, id);
}

/// A downloaded content folder (one with `details.json`).
typedef OfflineContentId = ({String supplier, String id});

/// Reads and edits the offline storage under [root]. Unfinished (`.part`) files are ignored; contents without
/// `details.json` are not listed.
class OfflineStorage {
  final Directory root;

  /// Installed supplier names, to split content folder names (see [OfflineLayout.parseContentDirName]).
  final Iterable<String> Function() suppliers;

  OfflineStorage(this.root, {Iterable<String> Function()? suppliers}) : suppliers = suppliers ?? (() => const []);

  Directory contentDir(String supplier, String id) =>
      Directory(p.join(root.path, OfflineLayout.contentDirName(supplier, id)));

  // Scans run in background isolates with sync IO: awaiting one async call per file on the UI isolate (thousands of
  // manga pages) took tens of seconds, each call waiting behind the frames.

  /// Downloaded contents, newest first; only their folders are listed, not the items.
  Future<List<OfflineContentId>> contentIds() async =>
      root.existsSync() ? _contentIdsInIsolate(root.path, suppliers().toList()) : const [];

  /// Details and finished items of one content; null when it is not downloaded.
  Future<DownloadedContent?> content(String supplier, String id) async {
    final dir = contentDir(supplier, id);
    return dir.existsSync() ? _contentInIsolate(supplier, id, dir.path) : null;
  }

  /// Bytes taken by one content's files (every page is stat'ed, so it is loaded apart from [content]).
  Future<int> size(String supplier, String id) async {
    final dir = contentDir(supplier, id);
    return dir.existsSync() ? _sizeInIsolate(dir.path) : 0;
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

  /// The nearest item before [number] with downloaded files matching [has]: the source a batch switched to is kept
  /// for the next items.
  Future<DownloadedItem?> itemBefore(
    String supplier,
    String id,
    int number, {
    required bool Function(DownloadedItem item) has,
  }) async {
    final dir = contentDir(supplier, id);
    if (!dir.existsSync()) return null;
    final numbers = <int, Directory>{};
    await for (final entity in dir.list()) {
      final n = int.tryParse(p.basename(entity.path));
      if (entity is Directory && n != null && n < number) numbers[n] = entity;
    }
    for (final n in numbers.keys.toList()..sort((a, b) => b.compareTo(a))) {
      final item = _readItem(n, numbers[n]!);
      if (has(item)) return item;
    }
    return null;
  }
}

// Top-level so the isolate closures capture only these arguments, not an [OfflineStorage] (its `suppliers` callback
// may hold a Riverpod ref).
Future<List<OfflineContentId>> _contentIdsInIsolate(String root, List<String> suppliers) =>
    Isolate.run(() => _contentIdsSync(Directory(root), suppliers), debugName: 'OfflineStorage.contentIds');

Future<DownloadedContent?> _contentInIsolate(String supplier, String id, String dir) => Isolate.run(() {
  final directory = Directory(dir);
  return directory.existsSync() ? _readSync(supplier, id, directory) : null;
}, debugName: 'OfflineStorage.content');

Future<int> _sizeInIsolate(String dir) => Isolate.run(() {
  final directory = Directory(dir);
  if (!directory.existsSync()) return 0;
  var size = 0;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File) size += entity.statSync().size;
  }
  return size;
}, debugName: 'OfflineStorage.size');

List<OfflineContentId> _contentIdsSync(Directory root, List<String> suppliers) {
  if (!root.existsSync()) return const [];
  final contents = <(OfflineContentId, DateTime)>[];
  for (final entity in root.listSync()) {
    if (entity is! Directory) continue;
    final names = OfflineLayout.parseContentDirName(p.basename(entity.path), suppliers: suppliers);
    if (names == null || !File(p.join(entity.path, OfflineLayout.detailsFile)).existsSync()) continue;
    contents.add(((supplier: names.$1, id: names.$2), entity.statSync().modified));
  }
  contents.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (id, _) in contents) id];
}

/// Null without a readable `details.json` (an unreadable one is skipped silently: loggers of the scan isolate have no
/// listener).
DownloadedContent? _readSync(String supplier, String id, Directory dir) {
  final detailsFile = File(p.join(dir.path, OfflineLayout.detailsFile));
  if (!detailsFile.existsSync()) return null;
  OfflineDetails details;
  try {
    details = OfflineDetails.fromJson(jsonDecode(detailsFile.readAsStringSync()) as Map<String, Object?>);
  } catch (_) {
    return null;
  }

  final items = <int, DownloadedItem>{};
  for (final entity in dir.listSync()) {
    final number = int.tryParse(p.basename(entity.path));
    if (entity is! Directory || number == null) continue;
    final item = _readItem(number, entity);
    if (!item.isEmpty) items[number] = item;
  }
  final sorted = Map.fromEntries(items.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  return DownloadedContent(supplier: supplier, id: id, details: details, items: sorted, dir: dir);
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
