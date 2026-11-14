import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../network/http_client.dart';
import 'hls_rewriter.dart';
import 'ts_dejunker.dart';

final _log = Logger('HlsProxy');

/// Local HLS proxy for `hlsProxy` sources (spec-12 §12.4): rewrites playlists and dejunks clear TS segments.
/// Loopback only, ephemeral port; one instance per video backend.
class HlsProxy {
  static const _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailers',
    'transfer-encoding',
    'upgrade',
    'host',
  };

  // Not forwarded either: ranges are handled per endpoint, and byte counts must match the raw upstream body.
  static const _localHeaders = {'range', 'if-range', 'accept-encoding', 'content-length'};

  final http.Client _client;
  final HttpServer _server;

  HlsProxy._(this._client, this._server) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<HlsProxy> start(http.Client client) async =>
      HlsProxy._(client, await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  int get port => _server.port;

  /// URL to hand to the player for the upstream master (or media) playlist.
  Uri masterUrl(Uri upstream) => Uri.parse('http://127.0.0.1:$port${hlsProxyPlaylistPath('master', upstream)}');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final upstream = _upstreamUrl(request.uri);
      if (upstream == null) return await _status(response, HttpStatus.badRequest);
      switch (request.uri.path) {
        case '/master' || '/stream':
          await _playlist(request, upstream);
        case '/segment':
          final params = request.uri.queryParameters;
          final fmp4 = params['format'] == 'fmp4';
          if (fmp4 || params['passthrough'] == 'true') {
            await _passthrough(request, upstream, fmp4: fmp4);
          } else {
            await _dejunked(request, upstream);
          }
        default:
          await _status(response, HttpStatus.notFound);
      }
    } on _HeadersSent catch (e) {
      // The player sees a truncated body (Content-Length mismatch) and reconnects.
      _log.warning('Segment failed after headers were sent: ${e.cause}');
      await _closeQuietly(response);
    } catch (e) {
      _log.warning('Proxy request ${request.uri} failed', e);
      await _status(response, HttpStatus.badGateway);
    }
  }

  static Uri? _upstreamUrl(Uri requestUri) {
    final url = requestUri.queryParameters['url'];
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    return uri;
  }

  Future<http.StreamedResponse> _fetch(HttpRequest request, Uri upstream, {bool forwardRange = false}) {
    final out = http.Request('GET', upstream);
    request.headers.forEach((name, values) {
      if (_hopByHopHeaders.contains(name) || _localHeaders.contains(name)) return;
      out.headers[name] = values.join(', ');
    });
    if (forwardRange) {
      for (final name in const ['range', 'if-range']) {
        final value = request.headers.value(name);
        if (value != null) out.headers[name] = value;
      }
    }
    return _client.send(out).timeout(httpTimeout);
  }

  Future<void> _playlist(HttpRequest request, Uri upstream) async {
    final upstreamResponse = await _fetch(request, upstream);
    if (upstreamResponse.statusCode >= 400) return _upstreamError(request.response, upstreamResponse);
    final body = await http.ByteStream(upstreamResponse.stream.timeout(httpTimeout)).toBytes();
    final rewritten = rewriteHlsPlaylist(utf8.decode(body, allowMalformed: true), upstream);
    await _sendBytes(request, utf8.encode(rewritten), 'application/vnd.apple.mpegurl');
  }

  Future<void> _passthrough(HttpRequest request, Uri upstream, {required bool fmp4}) async {
    final upstreamResponse = await _fetch(request, upstream, forwardRange: true);
    if (upstreamResponse.statusCode >= 400) return _upstreamError(request.response, upstreamResponse);
    final response = request.response;
    final headers = upstreamResponse.headers;
    response.statusCode = upstreamResponse.statusCode;
    response.headers.contentType = fmp4 ? ContentType('video', 'mp4') : ContentType('video', 'mp2t');
    for (final name in const ['content-range', 'accept-ranges']) {
      final value = headers[name];
      if (value != null) response.headers.set(name, value);
    }
    final length = upstreamResponse.contentLength;
    if (length == null) {
      final body = await http.ByteStream(upstreamResponse.stream.timeout(httpTimeout)).toBytes();
      response.contentLength = body.length;
      response.add(body);
      return response.close();
    }
    response.contentLength = length;
    try {
      await response.addStream(upstreamResponse.stream.timeout(httpTimeout));
    } catch (e) {
      throw _HeadersSent(e);
    }
    await response.close();
  }

  Future<void> _dejunked(HttpRequest request, Uri upstream) async {
    final upstreamResponse = await _fetch(request, upstream);
    if (upstreamResponse.statusCode >= 400) return _upstreamError(request.response, upstreamResponse);
    final range = request.headers.value('range')?.replaceAll(' ', '');
    final length = upstreamResponse.contentLength;
    final dejunker = TsDejunker();
    final chunks = StreamIterator(upstreamResponse.stream.timeout(httpTimeout));
    try {
      if (length != null && (range == null || range == 'bytes=0-')) {
        await _streamDejunked(request.response, chunks, dejunker, length, partial: range != null);
      } else {
        final out = BytesBuilder(copy: false);
        while (await chunks.moveNext()) {
          final emitted = dejunker.feed(chunks.current);
          if (emitted != null) out.add(emitted);
        }
        final tail = dejunker.finish();
        if (tail != null) out.add(tail);
        await _sendBytes(request, out.takeBytes(), 'video/mp2t');
      }
    } finally {
      await chunks.cancel();
    }
  }

  /// Streams the segment, sending headers once the sync point (and so the final length) is known.
  Future<void> _streamDejunked(
    HttpResponse response,
    StreamIterator<List<int>> chunks,
    TsDejunker dejunker,
    int upstreamLength, {
    required bool partial,
  }) async {
    Uint8List? first;
    while (first == null && await chunks.moveNext()) {
      first = dejunker.feed(chunks.current);
    }
    first ??= dejunker.finish();
    if (first == null) throw StateError('Dejunker emitted nothing');

    final length = upstreamLength - dejunker.filteredBytes;
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.contentLength = length;
    if (partial) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-${length - 1}/$length');
    }
    try {
      response.add(first);
      while (await chunks.moveNext()) {
        response.add(dejunker.feed(chunks.current)!);
        await response.flush();
      }
      await response.close();
    } catch (e) {
      throw _HeadersSent(e);
    }
  }

  /// Replies with [bytes], honoring a single `Range` of the request (against these bytes).
  static Future<void> _sendBytes(HttpRequest request, List<int> bytes, String contentType) async {
    final response = request.response;
    response.headers.contentType = ContentType.parse(contentType);
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    final header = request.headers.value('range');
    if (header == null) {
      response.contentLength = bytes.length;
      response.add(bytes);
      return response.close();
    }
    final range = _parseRange(header, bytes.length);
    if (range == null) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${bytes.length}');
      response.contentLength = 0;
      return response.close();
    }
    final (start, end) = range;
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${bytes.length}');
    response.contentLength = end - start + 1;
    response.add(bytes.sublist(start, end + 1));
    return response.close();
  }

  /// Inclusive `(start, end)` of a single `bytes=` range, or null when unsatisfiable.
  static (int, int)? _parseRange(String header, int total) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.replaceAll(' ', ''));
    if (match == null || total == 0) return null;
    final first = int.tryParse(match[1]!);
    final last = int.tryParse(match[2]!);
    if (first == null) {
      if (last == null || last == 0) return null;
      return (total - (last > total ? total : last), total - 1);
    }
    if (first >= total || (last != null && last < first)) return null;
    return (first, last == null || last >= total ? total - 1 : last);
  }

  static Future<void> _upstreamError(HttpResponse response, http.StreamedResponse upstream) async {
    unawaited(upstream.stream.listen(null).cancel());
    await _status(response, upstream.statusCode);
  }

  static Future<void> _status(HttpResponse response, int status) async {
    try {
      response.statusCode = status;
      response.contentLength = 0;
    } catch (_) {
      // Headers already sent; closing is all that is left.
    }
    await _closeQuietly(response);
  }

  static Future<void> _closeQuietly(HttpResponse response) async {
    try {
      await response.close();
    } catch (_) {}
  }
}

class _HeadersSent implements Exception {
  final Object cause;

  const _HeadersSent(this.cause);
}
