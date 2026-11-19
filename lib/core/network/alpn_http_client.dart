import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http2/transport.dart';

import 'http2_connection_pool.dart';

/// `package:http` client speaking HTTP/2 to every HTTPS origin that negotiates `h2` via ALPN and HTTP/1.1 (`IOClient`)
/// to the rest and to plain `http://`. Pure Dart: works in any isolate and FlutterEngine (e.g. the download service).
///
/// On top of the transport it handles redirects (also across protocols), `Abortable` requests, transparent gzip (only
/// when the caller set neither `Accept-Encoding` nor `Range`), one retry of idempotent requests refused by a closing
/// connection (GOAWAY) and backpressure (a paused body stops HTTP/2 window updates).
class AlpnHttpClient extends http.BaseClient {
  final String userAgent;
  final Duration connectTimeout;
  final Duration idleTimeout;
  final SecurityContext? _context;
  final IOClient _http1;
  final _pools = <String, Http2OriginPool>{};
  final _http1Origins = <String>{};
  bool _closed = false;

  AlpnHttpClient({
    required this.userAgent,
    this.connectTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
    SecurityContext? context,
  }) : _context = context,
       _http1 = IOClient(
         HttpClient(context: context)
           ..userAgent = userAgent
           ..connectionTimeout = connectTimeout
           ..idleTimeout = idleTimeout,
       );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('HTTP request failed. Client is already closed.', request.url);
    final abort = _AbortSignal(request is http.Abortable ? request.abortTrigger : null);
    var body = await request.finalize().toBytes();
    var method = request.method;
    var url = request.url;
    final headers = {for (final e in request.headers.entries) e.key.toLowerCase(): e.value};

    for (var redirects = 0; ; redirects++) {
      if (abort.fired) throw http.RequestAbortedException(url);
      final response = await _sendOnce(method, url, headers, body, abort, request.persistentConnection);
      final status = response.statusCode;
      final location = response.headers['location'];
      final redirect = _redirectStatuses.contains(status);
      if (!request.followRedirects || !redirect || location == null) {
        return http.StreamedResponse(
          response.stream,
          status,
          contentLength: response.contentLength,
          request: request,
          headers: response.headers,
          isRedirect: redirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }
      unawaited(response.stream.listen(null, onError: (Object _) {}).cancel());
      if (redirects >= request.maxRedirects) throw http.ClientException('Redirect limit exceeded', url);
      if ((status == 303 && method != 'HEAD') || ((status == 301 || status == 302) && method == 'POST')) {
        method = 'GET';
        body = Uint8List(0);
        headers
          ..remove('content-type')
          ..remove('content-length');
      }
      final next = url.resolve(location);
      if (next.host != url.host || next.port != url.port) headers.remove('authorization');
      url = next;
    }
  }

  @override
  void close() {
    _closed = true;
    for (final pool in _pools.values) {
      pool.close();
    }
    _pools.clear();
    _http1.close();
  }

  Future<http.StreamedResponse> _sendOnce(
    String method,
    Uri url,
    Map<String, String> headers,
    Uint8List body,
    _AbortSignal abort,
    bool persistentConnection,
  ) async {
    final origin = '${url.host}:${url.port}';
    if (url.scheme == 'https' && !_http1Origins.contains(origin)) {
      final pool = _pools.putIfAbsent(
        origin,
        () => Http2OriginPool(host: url.host, port: url.port, connect: _connect, idleTimeout: idleTimeout),
      );
      try {
        return await _sendHttp2(pool, method, url, headers, body, abort);
      } on Http2NotNegotiated {
        _http1Origins.add(origin);
        if (identical(_pools[origin], pool)) _pools.remove(origin)?.close();
      } on http.ClientException {
        rethrow;
      } catch (e, stackTrace) {
        Error.throwWithStackTrace(http.ClientException('$e', url), stackTrace);
      }
    }
    final out = http.AbortableRequest(method, url, abortTrigger: abort.future)
      ..followRedirects = false
      ..persistentConnection = persistentConnection
      ..headers.addAll(headers);
    if (body.isNotEmpty) out.bodyBytes = body;
    return _http1.send(out);
  }

  Future<SecureSocket> _connect(String host, int port) => SecureSocket.connect(
    host,
    port,
    context: _context,
    supportedProtocols: const ['h2', 'http/1.1'],
    timeout: connectTimeout,
  );

  Future<http.StreamedResponse> _sendHttp2(
    Http2OriginPool pool,
    String method,
    Uri url,
    Map<String, String> headers,
    Uint8List body,
    _AbortSignal abort,
  ) async {
    final decode = method != 'HEAD' && !headers.containsKey('accept-encoding') && !headers.containsKey('range');
    final requestHeaders = _requestHeaders(method, url, headers, body, decode: decode);
    try {
      return await _exchange(pool, method, url, requestHeaders, body, abort, decode: decode, canRetry: true);
    } on _Retry {
      return _exchange(pool, method, url, requestHeaders, body, abort, decode: decode, canRetry: false);
    }
  }

  /// One HTTP/2 stream; completes with the response headers while the body keeps streaming.
  Future<http.StreamedResponse> _exchange(
    Http2OriginPool pool,
    String method,
    Uri url,
    List<Header> requestHeaders,
    Uint8List body,
    _AbortSignal abort, {
    required bool decode,
    required bool canRetry,
  }) async {
    final lease = await pool.acquire();
    if (abort.fired) {
      lease.release();
      throw http.RequestAbortedException(url);
    }
    final ClientTransportStream stream;
    try {
      stream = lease.transport.makeRequest(requestHeaders, endStream: body.isEmpty);
    } on StateError catch (e) {
      // The connection started closing after it was picked.
      lease.release();
      if (canRetry) throw const _Retry();
      throw http.ClientException(e.message, url);
    }
    if (body.isNotEmpty) stream.sendData(body, endStream: true);

    final status = Completer<int>();
    final responseHeaders = <String, String>{};
    final controller = StreamController<List<int>>();
    var done = false;
    var pausedUntilListen = false;
    late final StreamSubscription<StreamMessage> subscription;

    void finish() {
      if (done) return;
      done = true;
      lease.release();
    }

    void fail(Object error, StackTrace stackTrace) {
      if (!status.isCompleted) {
        status.completeError(error, stackTrace);
      } else if (!controller.isClosed) {
        controller.addError(error, stackTrace);
        unawaited(controller.close());
      }
    }

    subscription = stream.incomingMessages.listen(
      (message) {
        if (message is HeadersStreamMessage) {
          if (status.isCompleted) return; // trailers
          final parsed = _parseHeaders(message.headers);
          final code = int.tryParse(parsed.remove(':status') ?? '');
          if (code == null) {
            finish();
            stream.terminate();
            unawaited(subscription.cancel());
            fail(http.ClientException('Invalid HTTP/2 response status', url), StackTrace.current);
            return;
          }
          if (code < 200) return; // informational
          responseHeaders.addAll(parsed);
          status.complete(code);
          if (!controller.hasListener) {
            pausedUntilListen = true;
            subscription.pause();
          }
        } else if (message is DataStreamMessage && message.bytes.isNotEmpty) {
          controller.add(message.bytes);
        }
      },
      onDone: () {
        finish();
        if (status.isCompleted) {
          unawaited(controller.close());
        } else {
          fail(http.ClientException('HTTP/2 stream closed before the response headers', url), StackTrace.current);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        finish();
        // Refused by a closing connection (GOAWAY) or the connection died before answering: safe to resend.
        if (!status.isCompleted && canRetry && _idempotentMethods.contains(method) && !lease.connection.isOpen) {
          status.completeError(const _Retry());
          return;
        }
        fail(error is http.ClientException ? error : http.ClientException('$error', url), stackTrace);
      },
      cancelOnError: true,
    );

    controller
      ..onListen = () {
        if (!pausedUntilListen) return;
        pausedUntilListen = false;
        subscription.resume();
      }
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = () {
        if (!done) {
          finish();
          stream.terminate();
        }
        return subscription.cancel();
      };

    unawaited(
      abort.future?.then((_) {
        if (done) return;
        finish();
        stream.terminate();
        unawaited(subscription.cancel());
        fail(http.RequestAbortedException(url), StackTrace.current);
      }),
    );

    final code = await status.future;
    var bodyStream = controller.stream;
    var contentLength = int.tryParse(responseHeaders['content-length'] ?? '');
    if (decode && responseHeaders['content-encoding']?.toLowerCase() == 'gzip' && code != 204 && code != 304) {
      bodyStream = bodyStream.transform(gzip.decoder);
      responseHeaders
        ..remove('content-encoding')
        ..remove('content-length');
      contentLength = null;
    }
    return http.StreamedResponse(bodyStream, code, contentLength: contentLength, headers: responseHeaders);
  }

  List<Header> _requestHeaders(
    String method,
    Uri url,
    Map<String, String> headers,
    Uint8List body, {
    required bool decode,
  }) {
    final host = url.host.contains(':') ? '[${url.host}]' : url.host;
    final path = url.path.isEmpty ? '/' : url.path;
    return [
      Header.ascii(':method', method),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', url.port == 443 ? host : '$host:${url.port}'),
      Header.ascii(':path', url.hasQuery ? '$path?${url.query}' : path),
      for (final MapEntry(:key, :value) in headers.entries)
        if (!_connectionHeaders.contains(key) && (key != 'te' || value == 'trailers'))
          Header(ascii.encode(key), utf8.encode(value)),
      if (!headers.containsKey('user-agent')) Header.ascii('user-agent', userAgent),
      if (decode) Header.ascii('accept-encoding', 'gzip'),
      if (body.isNotEmpty && !headers.containsKey('content-length')) Header.ascii('content-length', '${body.length}'),
    ];
  }
}

Map<String, String> _parseHeaders(List<Header> headers) {
  final result = <String, String>{};
  for (final header in headers) {
    final value = latin1.decode(header.value);
    result.update(latin1.decode(header.name).toLowerCase(), (existing) => '$existing, $value', ifAbsent: () => value);
  }
  return result;
}

/// Normalizes an `Abortable.abortTrigger` (which may also complete with an error) and records that it fired.
class _AbortSignal {
  final Future<void>? future;
  bool fired = false;

  _AbortSignal(Future<void>? trigger) : future = trigger?.then<void>((_) {}, onError: (Object _) {}) {
    future?.then((_) => fired = true);
  }
}

class _Retry implements Exception {
  const _Retry();
}

const _redirectStatuses = {301, 302, 303, 307, 308};

const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE', 'TRACE'};

/// Forbidden on HTTP/2 streams (RFC 9113 §8.2.2); `host` is carried by `:authority`.
const _connectionHeaders = {'connection', 'keep-alive', 'proxy-connection', 'transfer-encoding', 'upgrade', 'host'};
