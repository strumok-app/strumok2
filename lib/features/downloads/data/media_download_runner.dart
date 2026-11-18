import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/file_downloader.dart';
import '../../../core/network/http_client.dart';
import '../domain/download_task.dart';
import '../domain/offline_layout.dart';
import 'download_resolver.dart';
import 'hls_downloader.dart';

final _log = Logger('MediaDownloadRunner');

/// (fraction 0..1, bytes downloaded so far in this run).
typedef DownloadProgressReporter = void Function(double progress, int bytes);

/// Downloads one task's files; the engine calls it when the scheduler starts the task.
abstract interface class DownloadTaskRunner {
  /// Completes when the files are in place; throws [DownloadCanceledException] when [cancelToken] fires, and any
  /// other error when the task failed (classified with [classifyDownloadError]).
  Future<void> run(
    DownloadRequest request, {
    required DownloadProgressReporter onProgress,
    required DownloadCancelToken cancelToken,
  });
}

/// Spec-08 §8.2: progressive video (Range resume into `.part`), HLS (spec-12 §12.5), subtitles alongside the video,
/// manga pages with bounded parallelism. Network errors and 5xx are retried with backoff; a 4xx re-resolves the
/// source once (the link may have expired), then fails.
class MediaDownloadRunner implements DownloadTaskRunner {
  static const mangaParallelism = 4;

  final http.Client client;
  final DownloadResolver resolver;
  final HlsDownloader hls;
  final int retries;
  final Duration Function(int attempt) backoff;

  MediaDownloadRunner({
    required this.client,
    required this.resolver,
    HlsDownloader? hls,
    this.retries = 3,
    Duration Function(int attempt)? backoff,
  }) : hls = hls ?? HlsDownloader(client),
       backoff = backoff ?? ((attempt) => Duration(seconds: 2 << attempt));

  @override
  Future<void> run(
    DownloadRequest request, {
    required DownloadProgressReporter onProgress,
    required DownloadCancelToken cancelToken,
  }) async {
    var reResolved = false;
    for (var attempt = 0; ;) {
      _checkCanceled(cancelToken);
      try {
        final resolved = await resolver.resolve(request);
        _checkCanceled(cancelToken);
        return await _download(request, resolved, onProgress, cancelToken);
      } on DownloadCanceledException {
        rethrow;
      } catch (e) {
        _checkCanceled(cancelToken);
        final failure = classifyDownloadError(e);
        if (failure == DownloadFailure.unavailable && e is HttpStatusException && !reResolved) {
          _log.info('${request.id}: HTTP ${e.statusCode}, resolving the source again');
          reResolved = true;
          continue;
        }
        if (failure != DownloadFailure.network || attempt >= retries) rethrow;
        _log.info('${request.id}: attempt ${attempt + 1} failed, retrying', e);
        await Future.any([Future<void>.delayed(backoff(attempt)), cancelToken.whenCanceled]);
        attempt++;
      }
    }
  }

  Future<void> _download(
    DownloadRequest request,
    ResolvedDownload resolved,
    DownloadProgressReporter onProgress,
    DownloadCancelToken cancelToken,
  ) async {
    final itemDir = p.join(
      request.root,
      OfflineLayout.contentDirName(request.supplier, request.contentId),
      '${request.itemIndex}',
    );
    switch (resolved) {
      case ResolvedVideo(:final video, :final subtitle):
        final target = File(p.join(itemDir, OfflineLayout.videoFileName(video.description)));
        if (!target.existsSync()) await _downloadVideo(video, target, onProgress, cancelToken);
        if (subtitle != null) await _downloadSubtitle(subtitle, itemDir, cancelToken);
      case ResolvedManga():
        await _downloadPages(
          resolved,
          Directory(p.join(itemDir, OfflineLayout.pagesDirName(resolved.description))),
          onProgress,
          cancelToken,
        );
    }
    onProgress(1, 0);
  }

  Future<void> _downloadVideo(
    ResolvedFile video,
    File target,
    DownloadProgressReporter onProgress,
    DownloadCancelToken cancelToken,
  ) async {
    void hlsProgress(int done, int total, int bytes) => onProgress(total == 0 ? 0 : done / total, bytes);

    // An earlier HLS attempt left its resume state; the link is a playlist even without an `.m3u8` path.
    if (File('${target.path}.part.json').existsSync() || video.link.path.toLowerCase().endsWith('.m3u8')) {
      return hls.download(
        playlistUri: video.link,
        target: target,
        headers: video.headers,
        onProgress: hlsProgress,
        cancelToken: cancelToken,
      );
    }

    final part = File('${target.path}.part');
    await part.parent.create(recursive: true);
    final existing = part.existsSync() ? part.lengthSync() : 0;
    final response = await _send(video.link, video.headers, cancelToken, from: existing);
    if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable && existing > 0) {
      // The partial file does not fit the resource (it changed): start over.
      await response.stream.drain<void>().catchError((_) {});
      await part.delete();
      return _downloadVideo(video, target, onProgress, cancelToken);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>().catchError((_) {});
      throw HttpStatusException(video.link, response.statusCode);
    }

    final chunks = StreamIterator(response.stream.timeout(httpTimeout));
    final head = <int>[];
    final buffered = <List<int>>[];
    while (head.length < 64 && await chunks.moveNext()) {
      buffered.add(chunks.current);
      head.addAll(chunks.current);
    }
    if (isHlsResponse(video.link, contentType: response.headers['content-type'], head: head)) {
      final builder = BytesBuilder(copy: false)..add(head);
      while (await chunks.moveNext()) {
        builder.add(chunks.current);
      }
      return hls.download(
        playlistUri: video.link,
        playlistText: utf8.decode(builder.takeBytes(), allowMalformed: true),
        target: target,
        headers: video.headers,
        onProgress: hlsProgress,
        cancelToken: cancelToken,
      );
    }

    final append = response.statusCode == HttpStatus.partialContent && existing > 0;
    final total = response.contentLength == null ? null : response.contentLength! + (append ? existing : 0);
    var received = append ? existing : 0;
    var downloaded = 0;
    final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
    try {
      void write(List<int> chunk) {
        sink.add(chunk);
        received += chunk.length;
        downloaded += chunk.length;
        onProgress(total == null || total == 0 ? 0 : min(1, received / total), downloaded);
      }

      buffered.forEach(write);
      while (await chunks.moveNext()) {
        _checkCanceled(cancelToken);
        write(chunks.current);
      }
    } finally {
      await chunks.cancel();
      await sink.flush();
      await sink.close();
    }
    _checkCanceled(cancelToken);
    if (total != null && received < total) {
      throw http.ClientException('Connection closed after $received of $total bytes', video.link);
    }
    await part.rename(target.path);
  }

  /// Best effort: a video without its subtitles is still useful.
  Future<void> _downloadSubtitle(ResolvedFile subtitle, String itemDir, DownloadCancelToken cancelToken) async {
    final target = File(p.join(itemDir, OfflineLayout.subtitleFileName(subtitle.description)));
    if (target.existsSync()) return;
    try {
      await downloadToFile(client, subtitle.link, target, headers: subtitle.headers, cancelToken: cancelToken);
    } on DownloadCanceledException {
      rethrow;
    } catch (e) {
      _log.warning('Subtitles ${subtitle.description} failed to download', e);
    }
  }

  /// Pages go into `<dir>.part/` (already downloaded ones are kept when resuming), renamed when all are there.
  Future<void> _downloadPages(
    ResolvedManga manga,
    Directory target,
    DownloadProgressReporter onProgress,
    DownloadCancelToken cancelToken,
  ) async {
    if (target.existsSync()) return;
    final part = Directory('${target.path}${OfflineLayout.partSuffix}');
    await part.create(recursive: true);
    final total = manga.pages.length;
    var done = 0, bytes = 0;
    var next = 0;
    var failed = false;

    Future<void> worker() async {
      while (next < total && !failed) {
        final index = next++;
        _checkCanceled(cancelToken);
        final url = manga.pages[index];
        final file = File(p.join(part.path, OfflineLayout.pageFileName(index, url)));
        if (!file.existsSync()) {
          try {
            await downloadToFile(client, Uri.parse(url), file, headers: manga.headers, cancelToken: cancelToken);
          } catch (_) {
            failed = true;
            rethrow;
          }
        }
        done++;
        bytes += file.lengthSync();
        onProgress(done / total, bytes);
      }
    }

    await Future.wait([for (var i = 0; i < min(mangaParallelism, total); i++) worker()], eagerError: true);
    _checkCanceled(cancelToken);
    await part.rename(target.path);
  }

  Future<http.StreamedResponse> _send(
    Uri uri,
    Map<String, String>? headers,
    DownloadCancelToken cancelToken, {
    int from = 0,
  }) {
    final request = http.AbortableRequest('GET', uri, abortTrigger: cancelToken.whenCanceled);
    if (headers != null) request.headers.addAll(headers);
    if (from > 0) request.headers['range'] = 'bytes=$from-';
    return client.send(request).timeout(httpTimeout);
  }

  static void _checkCanceled(DownloadCancelToken token) {
    if (token.isCanceled) throw const DownloadCanceledException();
  }
}
