import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../core/hls/hls_aes128.dart';
import '../../../core/hls/hls_playlist.dart';
import '../../../core/hls/ts_dejunker.dart';
import '../../../core/network/file_downloader.dart';
import '../../../core/network/http_client.dart';

final _log = Logger('HlsDownloader');

/// (segments done, segments total, bytes written).
typedef HlsProgressCallback = void Function(int done, int total, int bytes);

/// Unsupported encryption (e.g. `SAMPLE-AES`) or a playlist without media segments.
class UnsupportedHlsException implements Exception {
  final String message;

  const UnsupportedHlsException(this.message);

  @override
  String toString() => 'Unsupported HLS: $message';
}

/// Whether a response is an HLS playlist (spec-12 §12.5): `.m3u8` path, HLS content type, or a body starting with
/// `#EXTM3U` (sniffing; [head] is the start of the body when available).
bool isHlsResponse(Uri uri, {String? contentType, List<int>? head}) {
  if (uri.path.toLowerCase().endsWith('.m3u8')) return true;
  final type = contentType?.toLowerCase() ?? '';
  if (type.contains('mpegurl')) return true;
  if (head == null) return false;
  const marker = '#EXTM3U';
  var i = 0;
  // A UTF-8 BOM or leading whitespace may precede the tag.
  if (head.length >= 3 && head[0] == 0xEF && head[1] == 0xBB && head[2] == 0xBF) i = 3;
  while (i < head.length && (head[i] == 0x20 || head[i] == 0x0A || head[i] == 0x0D || head[i] == 0x09)) {
    i++;
  }
  if (head.length - i < marker.length) return false;
  return ascii.decode(head.sublist(i, i + marker.length), allowInvalid: true) == marker;
}

/// Downloads an HLS stream into one file (spec-12 §12.5): every clear TS segment is dejunked (whatever `hlsProxy`
/// says), AES-128 segments are decrypted and then dejunked, fMP4 init sections are written once per distinct map
/// and media segments untouched. Output goes to `<target>.part` and is renamed on success; a `.part.json` sidecar
/// lets an interrupted download continue from the next segment.
class HlsDownloader {
  final http.Client client;
  final int segmentRetries;
  final Duration retryDelay;

  HlsDownloader(this.client, {this.segmentRetries = 3, this.retryDelay = const Duration(seconds: 10)});

  Future<void> download({
    required Uri playlistUri,
    required File target,
    String? playlistText,
    Map<String, String>? headers,
    HlsProgressCallback? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final job = _Job(this, target, headers, onProgress, cancelToken);
    final text = playlistText ?? await job.fetchText(playlistUri);
    final playlist = HlsPlaylist.parse(text, playlistUri);
    switch (playlist) {
      case HlsMediaPlaylist():
        await job.downloadMedia(playlist);
      case HlsMasterPlaylist(:final variants):
        await job.downloadVariants(variants);
    }
  }
}

class _Job {
  final HlsDownloader owner;
  final File target;
  final Map<String, String>? headers;
  final HlsProgressCallback? onProgress;
  final DownloadCancelToken? cancelToken;
  final _keys = <Uri, Uint8List>{};

  _Job(this.owner, this.target, this.headers, this.onProgress, this.cancelToken);

  File get _part => File('${target.path}.part');

  File get _state => File('${target.path}.part.json');

  /// Highest bandwidth first; a variant that fails before writing anything falls back to the next one.
  // SPEC: separate audio renditions (`EXT-X-MEDIA TYPE=AUDIO`) are not muxed in; such variants download video-only.
  Future<void> downloadVariants(List<HlsVariant> variants) async {
    if (variants.isEmpty) throw const UnsupportedHlsException('master playlist without variants');
    final ordered = [...variants]..sort((a, b) => (b.bandwidth ?? -1).compareTo(a.bandwidth ?? -1));
    for (final (index, variant) in ordered.indexed) {
      var started = false;
      try {
        final playlist = HlsPlaylist.parse(await fetchText(variant.uri), variant.uri);
        if (playlist is! HlsMediaPlaylist) throw const FormatException('Variant is not a media playlist');
        await downloadMedia(playlist, onStarted: () => started = true);
        return;
      } catch (e) {
        _checkCanceled();
        if (started || index == ordered.length - 1) rethrow;
        _log.info('Variant ${variant.uri} failed, trying the next one', e);
      }
    }
  }

  Future<void> downloadMedia(HlsMediaPlaylist playlist, {void Function()? onStarted}) async {
    final segments = playlist.segments;
    if (segments.isEmpty) throw const UnsupportedHlsException('media playlist without segments');
    await target.parent.create(recursive: true);

    var resume = await _readState(segments.length);
    final raf = await _part.open(mode: resume == null ? FileMode.write : FileMode.append);
    try {
      if (resume != null) await raf.truncate(resume.bytes);
      var bytes = resume?.bytes ?? 0;
      var mapKey = resume?.mapKey;
      final first = resume?.segments ?? 0;
      resume = null;
      onProgress?.call(first, segments.length, bytes);

      for (var i = first; i < segments.length; i++) {
        _checkCanceled();
        final segment = segments[i];
        if (segment.map case final map?) {
          final key = '${map.uri}|${map.byteRange}';
          if (key != mapKey) {
            final init = await _withRetries(() => fetchBytes(map.uri, map.byteRange));
            await raf.writeFrom(init);
            bytes += init.length;
            mapKey = key;
          }
        }
        final data = await _withRetries(() => _segmentBytes(segment));
        await raf.writeFrom(data);
        await raf.flush();
        bytes += data.length;
        onStarted?.call();
        await _writeState(segments: i + 1, total: segments.length, bytes: bytes, mapKey: mapKey);
        onProgress?.call(i + 1, segments.length, bytes);
      }
    } finally {
      await raf.close();
    }
    if (target.existsSync()) await target.delete();
    await _part.rename(target.path);
    if (_state.existsSync()) await _state.delete();
  }

  /// Fetches (range), decrypts and dejunks one segment; a TS segment without sync is a [FormatException].
  Future<Uint8List> _segmentBytes(HlsSegment segment) async {
    var data = await fetchBytes(segment.uri, segment.byteRange);
    if (segment.key case final key?) {
      if (key.method != 'AES-128') throw UnsupportedHlsException('encryption ${key.method}');
      final uri = key.uri;
      if (uri == null) throw const FormatException('AES-128 key without URI');
      final keyBytes = _keys[uri] ??= await fetchBytes(uri);
      data = HlsAes128.decrypt(data, key: keyBytes, iv: key.iv ?? HlsAes128.sequenceIv(segment.sequence));
    }
    if (segment.isFmp4) return data;
    final dejunker = TsDejunker();
    final head = dejunker.feed(data);
    final tail = dejunker.finish();
    if (dejunker.filteredBytes > 0) _log.fine('Segment ${segment.sequence}: ${dejunker.filteredBytes} junk bytes');
    return head ?? tail!;
  }

  /// Network errors, 5xx and invalid segments are retried; 4xx never (spec-08: re-resolving is the caller's job).
  Future<T> _withRetries<T>(Future<T> Function() fetch) async {
    for (var attempt = 0; ; attempt++) {
      _checkCanceled();
      try {
        return await fetch();
      } catch (e) {
        _checkCanceled();
        final clientError = e is HttpStatusException && e.statusCode >= 400 && e.statusCode < 500;
        if (clientError || e is UnsupportedHlsException || attempt >= owner.segmentRetries) rethrow;
        _log.info('Segment request failed (attempt ${attempt + 1}), retrying', e);
        await _sleep(owner.retryDelay);
      }
    }
  }

  Future<String> fetchText(Uri uri) async => utf8.decode(await fetchBytes(uri), allowMalformed: true);

  /// Whole body; when the server ignores `Range` (200), the requested slice is cut out locally.
  Future<Uint8List> fetchBytes(Uri uri, [HlsByteRange? range]) async {
    final request = http.AbortableRequest('GET', uri, abortTrigger: cancelToken?.whenCanceled);
    if (headers != null) request.headers.addAll(headers!);
    if (range != null) request.headers['range'] = range.rangeHeader;
    final response = await owner.client.send(request).timeout(httpTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>().catchError((_) {});
      throw HttpStatusException(uri, response.statusCode);
    }
    final builder = BytesBuilder(copy: false);
    await response.stream.timeout(httpTimeout).forEach(builder.add);
    final body = builder.takeBytes();
    if (range != null && response.statusCode == 200 && body.length >= range.end) {
      return Uint8List.sublistView(body, range.offset, range.end);
    }
    return body;
  }

  Future<void> _sleep(Duration delay) async {
    final token = cancelToken;
    await (token == null ? Future<void>.delayed(delay) : Future.any([Future<void>.delayed(delay), token.whenCanceled]));
  }

  void _checkCanceled() {
    if (cancelToken?.isCanceled ?? false) throw const DownloadCanceledException();
  }

  /// Resume point of an earlier attempt at the same stream (same segment count, part file long enough).
  Future<({int segments, int bytes, String? mapKey})?> _readState(int total) async {
    try {
      if (!_state.existsSync() || !_part.existsSync()) return null;
      final json = jsonDecode(await _state.readAsString()) as Map<String, Object?>;
      final segments = (json['segments'] as num).toInt();
      final bytes = (json['bytes'] as num).toInt();
      if (json['total'] != total || segments > total || await _part.length() < bytes) return null;
      return (segments: segments, bytes: bytes, mapKey: json['map'] as String?);
    } catch (e) {
      _log.info('Ignoring unreadable HLS resume state', e);
      return null;
    }
  }

  Future<void> _writeState({required int segments, required int total, required int bytes, String? mapKey}) =>
      _state.writeAsString(jsonEncode({'segments': segments, 'total': total, 'bytes': bytes, 'map': mapKey}));
}
