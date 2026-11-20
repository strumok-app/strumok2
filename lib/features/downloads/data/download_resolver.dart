import 'dart:async';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';

import '../../../core/network/http_client.dart';
import '../domain/download_source.dart';
import '../domain/download_task.dart';
import 'hls_downloader.dart';
import 'offline_storage.dart';

/// A resolved file source: the link expires, so it is looked up again whenever a task (re)starts.
final class ResolvedFile {
  final String description;
  final Uri link;
  final Map<String, String>? headers;

  const ResolvedFile({required this.description, required this.link, this.headers});
}

sealed class ResolvedDownload {
  const ResolvedDownload();
}

final class ResolvedVideo extends ResolvedDownload {
  final ResolvedFile video;
  final ResolvedFile? subtitle;

  const ResolvedVideo(this.video, {this.subtitle});
}

final class ResolvedManga extends ResolvedDownload {
  final String description;
  final List<String> pages;
  final Map<String, String>? headers;

  const ResolvedManga({required this.description, required this.pages, this.headers});
}

/// Not worth retrying: the supplier, content, item or source is gone, or nothing can be done with the media.
class DownloadTaskException implements Exception {
  final DownloadFailure failure;
  final String message;

  const DownloadTaskException(this.failure, this.message);

  @override
  String toString() => 'Download failed (${failure.name}): $message';
}

/// Maps errors from resolving and downloading to the reason shown to the user.
DownloadFailure classifyDownloadError(Object error) => switch (error) {
  DownloadTaskException(:final failure) => failure,
  HttpStatusException(:final statusCode) when statusCode >= 400 && statusCode < 500 => DownloadFailure.unavailable,
  HttpStatusException() => DownloadFailure.network,
  UnsupportedHlsException() || FormatException() => DownloadFailure.invalidMedia,
  FileSystemException() => DownloadFailure.storage,
  // Socket errors, timeouts, client errors and supplier (FFI) errors, which are mostly network failures.
  _ => DownloadFailure.network,
};

/// Turns a queued request into links when its task starts (spec-02: links expire).
abstract interface class DownloadResolver {
  Future<ResolvedDownload> resolve(DownloadRequest request);
}

/// Looks the request up through the supplier: details → media item (by number) → source by
/// [chooseDownloadSource]: one of the preferred names, else the source of the nearest earlier downloaded item, else
/// the most similar name (manga keeps the `[language]` tag). The file is named after the source actually used.
class SupplierDownloadResolver implements DownloadResolver {
  final FutureOr<ContentSupplier?> Function(String name) supplierByName;

  SupplierDownloadResolver(this.supplierByName);

  @override
  Future<ResolvedDownload> resolve(DownloadRequest request) async {
    final supplier = await supplierByName(request.supplier);
    if (supplier == null) {
      throw DownloadTaskException(DownloadFailure.suppliers, 'Supplier ${request.supplier} is not available');
    }
    final details = await supplier.detailsById(request.contentId);
    if (details == null) {
      throw DownloadTaskException(DownloadFailure.sourceNotFound, 'Content ${request.contentId} not found');
    }
    final items = await details.mediaItems;
    final item = items.where((i) => i.number == request.itemIndex).firstOrNull;
    if (item == null) {
      throw DownloadTaskException(DownloadFailure.sourceNotFound, 'Item ${request.itemIndex} not found');
    }
    final sources = await item.sources;

    switch (request.kind) {
      case FileKind.manga:
        final previous = await _previous(request, (item) => item.mangaPages.keys);
        final source = _pick(sources.whereType<MangaMediaItemSource>().toList(), request, previous, strictTags: true);
        final pages = await source.allPages;
        if (pages.isEmpty) throw const DownloadTaskException(DownloadFailure.sourceNotFound, 'No manga pages');
        return ResolvedManga(description: source.description, pages: pages, headers: source.headers);
      case FileKind.video || FileKind.subtitle:
        final previous = await _previous(request, (item) => item.videos.keys);
        final video = _pick(sources.whereType<VideoMediaItemSource>().toList(), request, previous);
        final subtitle = request.subtitleName == null
            ? null
            : sources
                  .whereType<SubtitleMediaItemSource>()
                  .where((s) => s.description == request.subtitleName)
                  .firstOrNull;
        return ResolvedVideo(
          ResolvedFile(description: video.description, link: await video.link, headers: video.headers),
          subtitle: subtitle == null
              ? null
              : ResolvedFile(description: subtitle.description, link: await subtitle.link, headers: subtitle.headers),
        );
    }
  }

  /// Sources the nearest earlier item of this content was downloaded with (files are named after them).
  static Future<List<String>> _previous(
    DownloadRequest request,
    Iterable<String> Function(DownloadedItem) names,
  ) async {
    final item = await OfflineStorage(Directory(request.root))
        .itemBefore(request.supplier, request.contentId, request.itemIndex, has: (item) => names(item).isNotEmpty);
    return item == null ? const [] : names(item).toList();
  }

  static T _pick<T extends ContentMediaItemSource>(
    List<T> sources,
    DownloadRequest request,
    List<String> previous, {
    bool strictTags = false,
  }) {
    final index = chooseDownloadSource(
      [for (final s in sources) s.description],
      preferred: request.sourceNames,
      previous: previous,
      strictTags: strictTags,
    );
    if (index == null) {
      throw DownloadTaskException(DownloadFailure.sourceNotFound, 'No source like ${request.sourceNames}');
    }
    return sources[index];
  }
}
