import 'dart:async';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';

import '../../../core/network/http_client.dart';
import '../domain/download_task.dart';
import 'hls_downloader.dart';

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

/// Looks the request up through the supplier: details → media item (by number) → preferred source name,
/// else a source in the selected language (or the first when unknown).
/// The file is named after the source actually used.
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
        final source = _pick(
          sources.whereType<MangaMediaItemSource>().toList(),
          request.sourceNames,
          request.sourceLanguages,
        );
        final pages = await source.allPages;
        if (pages.isEmpty) throw const DownloadTaskException(DownloadFailure.sourceNotFound, 'No manga pages');
        return ResolvedManga(description: source.description, pages: pages, headers: source.headers);
      case FileKind.video || FileKind.subtitle:
        final video = _pick(
          sources.whereType<VideoMediaItemSource>().toList(),
          request.sourceNames,
          request.sourceLanguages,
        );
        final subtitles = sources.whereType<SubtitleMediaItemSource>().toList();
        // Unlike the video, missing subtitles only skip the subtitle file instead of failing the download.
        final subtitle = _pickSubtitle(subtitles, request.subtitleNames, request.subtitleLanguages);
        return ResolvedVideo(
          ResolvedFile(description: video.description, link: await video.link, headers: video.headers),
          subtitle: subtitle == null
              ? null
              : ResolvedFile(description: subtitle.description, link: await subtitle.link, headers: subtitle.headers),
        );
    }
  }

  static SubtitleMediaItemSource? _pickSubtitle(
    List<SubtitleMediaItemSource> subtitles,
    List<String> preferred,
    Map<String, ContentLanguage?> languages,
  ) {
    for (final name in preferred) {
      final match = subtitles.where((subtitle) => subtitle.description == name).firstOrNull;
      if (match != null) return match;
    }
    for (final name in preferred) {
      final language = languages[name];
      if (language == null) continue;
      final match = subtitles.where((subtitle) => subtitle.language == language).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  static T _pick<T extends ContentMediaItemSource>(
    List<T> sources,
    List<String> preferred,
    Map<String, ContentLanguage?> languages,
  ) {
    for (final name in preferred) {
      final index = sources.indexWhere((source) => source.description == name);
      if (index >= 0) return sources[index];
    }
    for (final name in preferred) {
      final language = languages[name];
      final index = sources.indexWhere((source) => language == null || source.language == language);
      if (index >= 0) return sources[index];
    }
    throw DownloadTaskException(DownloadFailure.sourceNotFound, 'No source matching $preferred and its languages');
  }
}
