import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http2/transport.dart';
import 'package:strumok/core/network/alpn_http_client.dart';

const _cert = 'test/fixtures/tls/localhost.crt';
const _key = 'test/fixtures/tls/localhost.key';

void main() {
  final serverContext = SecurityContext()
    ..useCertificateChain(_cert)
    ..usePrivateKey(_key);
  // `SecureServerSocket.bind(supportedProtocols:)` alone does not enable server-side ALPN.
  final h2Context = SecurityContext()
    ..useCertificateChain(_cert)
    ..usePrivateKey(_key)
    ..setAlpnProtocols(['h2'], true);
  late AlpnHttpClient client;

  setUp(() {
    client = AlpnHttpClient(
      userAgent: 'Strumok/test',
      idleTimeout: const Duration(milliseconds: 200),
      context: SecurityContext()..setTrustedCertificates(_cert),
    );
  });
  tearDown(() => client.close());

  Future<_H2Server> h2(_Handler handler) async {
    final server = await _H2Server.start(h2Context, handler);
    addTearDown(server.close);
    return server;
  }

  Future<HttpServer> h1(void Function(HttpRequest request) handler) async {
    final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, serverContext);
    server.listen(handler);
    addTearDown(() => server.close(force: true));
    return server;
  }

  test('multiplexes concurrent requests over one HTTP/2 connection', () async {
    final server = await h2((stream, request) async {
      stream.sendHeaders([
        Header.ascii(':status', '200'),
        Header.ascii('x-echo', request.headers['x-custom'] ?? ''),
        Header.ascii('x-ua', request.headers['user-agent'] ?? ''),
      ]);
      stream.sendData(utf8.encode(request.headers[':path']!), endStream: true);
    });

    final responses = await Future.wait([
      for (var i = 0; i < 5; i++) client.get(server.url('/item/$i?q=1'), headers: {'X-Custom': 'v$i'}),
    ]);

    expect(responses.map((r) => r.body), [for (var i = 0; i < 5; i++) '/item/$i?q=1']);
    expect(responses.map((r) => r.headers['x-echo']), [for (var i = 0; i < 5; i++) 'v$i']);
    expect(responses.first.headers['x-ua'], 'Strumok/test');
    expect(server.connections, 1);
  });

  test('sends the request body with its length', () async {
    final server = await h2((stream, request) async {
      stream.sendHeaders([Header.ascii(':status', '201')]);
      final text = '${request.headers[':method']} ${request.headers['content-length']} ${utf8.decode(request.body)}';
      stream.sendData(utf8.encode(text), endStream: true);
    });

    final response = await client.post(server.url('/form'), body: 'hello');

    expect(response.statusCode, 201);
    expect(response.body, 'POST 5 hello');
  });

  test('falls back to HTTP/1.1 when the server does not negotiate h2', () async {
    final server = await h1((request) {
      request.response.write('${request.protocolVersion} ${request.uri.path}');
      unawaited(request.response.close());
    });
    final uri = Uri.parse('https://localhost:${server.port}/a');

    expect((await client.get(uri)).body, '1.1 /a');
    expect((await client.get(uri)).body, '1.1 /a');
  });

  test('follows redirects from HTTP/2 to HTTP/1.1 and turns POST into GET on 303', () async {
    final target = await h1((request) {
      request.response.write('${request.method} ${request.uri.path}');
      unawaited(request.response.close());
    });
    final server = await h2((stream, request) async {
      stream.sendHeaders([
        Header.ascii(':status', '303'),
        Header.ascii('location', 'https://localhost:${target.port}/landing'),
      ], endStream: true);
    });

    final followed = await client.post(server.url('/form'), body: 'x');
    final notFollowed = await client.send(http.Request('GET', server.url('/form'))..followRedirects = false);

    expect(followed.statusCode, 200);
    expect(followed.body, 'GET /landing');
    expect(notFollowed.statusCode, 303);
    expect(notFollowed.isRedirect, isTrue);
  });

  test('abort while streaming the body resets the stream and keeps the connection usable', () async {
    final reset = Completer<void>();
    final server = await h2((stream, request) async {
      stream.sendHeaders([Header.ascii(':status', '200')]);
      if (request.headers[':path'] == '/slow') {
        stream.onTerminated = (_) => reset.complete();
        stream.sendData([1, 2, 3]);
      } else {
        stream.sendData(utf8.encode('ok'), endStream: true);
      }
    });
    final trigger = Completer<void>();

    final response = await client.send(http.AbortableRequest('GET', server.url('/slow'), abortTrigger: trigger.future));
    final firstChunk = Completer<void>();
    final error = Completer<Object>();
    response.stream.listen((_) => firstChunk.complete(), onError: error.complete);
    await firstChunk.future;
    trigger.complete();

    expect(await error.future, isA<http.RequestAbortedException>());
    await reset.future;
    expect((await client.get(server.url('/ok'))).body, 'ok');
    expect(server.connections, 1);
  });

  test('decodes gzip transparently, but not for range requests', () async {
    const payload = 'strumok strumok strumok';
    final acceptEncodings = <String?>[];
    final server = await h2((stream, request) async {
      final acceptEncoding = request.headers['accept-encoding'];
      acceptEncodings.add(acceptEncoding);
      final gzipped = acceptEncoding == 'gzip';
      final body = gzipped ? gzip.encode(utf8.encode(payload)) : utf8.encode(payload);
      stream.sendHeaders([
        Header.ascii(':status', '200'),
        Header.ascii('content-length', '${body.length}'),
        if (gzipped) Header.ascii('content-encoding', 'gzip'),
      ]);
      stream.sendData(body, endStream: true);
    });

    final decoded = await client.get(server.url('/g'));
    final ranged = await client.get(server.url('/g'), headers: {'Range': 'bytes=0-'});

    expect(decoded.body, payload);
    expect(decoded.headers['content-encoding'], isNull);
    expect(decoded.headers['content-length'], isNull);
    expect(ranged.headers['content-length'], '${payload.length}');
    expect(acceptEncodings, ['gzip', null]);
  });

  test('does not reuse a connection closed by the peer (GOAWAY) and closes idle ones', () async {
    final server = await h2((stream, request) async {
      stream.sendHeaders([Header.ascii(':status', '200')]);
      stream.sendData(utf8.encode('ok'), endStream: true);
    });

    expect((await client.get(server.url('/'))).body, 'ok');
    await server.finishConnections();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await client.get(server.url('/'))).body, 'ok');
    expect(server.connections, 2);

    await server.allClosed.timeout(const Duration(seconds: 5));
  });
}

typedef _Handler = Future<void> Function(ServerTransportStream stream, _Request request);

class _Request {
  final Map<String, String> headers;
  final List<int> body;

  _Request(this.headers, this.body);
}

class _H2Server {
  final SecureServerSocket _socket;
  final _open = <ServerTransportConnection>{};
  int connections = 0;
  Completer<void>? _allClosed;

  _H2Server._(this._socket);

  static Future<_H2Server> start(SecurityContext context, _Handler handler) async {
    final socket = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, context);
    final server = _H2Server._(socket);
    socket.listen((s) {
      server.connections++;
      final connection = ServerTransportConnection.viaSocket(s);
      server._open.add(connection);
      connection.incomingStreams.listen(
        (stream) async => handler(stream, await _read(stream)),
        onDone: () {
          server._open.remove(connection);
          if (server._open.isEmpty) server._allClosed?.complete();
        },
      );
    });
    return server;
  }

  Uri url(String path) => Uri.parse('https://localhost:${_socket.port}$path');

  Future<void> finishConnections() => Future.wait([for (final c in _open.toList()) c.finish()]);

  /// Completes once every accepted connection has been closed.
  Future<void> get allClosed {
    if (_open.isEmpty) return Future.value();
    return (_allClosed ??= Completer<void>()).future;
  }

  Future<void> close() async {
    await _socket.close();
    await Future.wait([for (final c in _open.toList()) c.terminate()]);
  }

  static Future<_Request> _read(ServerTransportStream stream) {
    final done = Completer<_Request>();
    final headers = <String, String>{};
    final body = <int>[];
    void complete() {
      if (!done.isCompleted) done.complete(_Request(headers, body));
    }

    stream.incomingMessages.listen(
      (message) {
        if (message is HeadersStreamMessage) {
          for (final header in message.headers) {
            headers[utf8.decode(header.name)] = utf8.decode(header.value);
          }
        } else if (message is DataStreamMessage) {
          body.addAll(message.bytes);
        }
        if (message.endStream) complete();
      },
      onDone: complete,
      onError: (Object _) {},
    );
    return done.future;
  }
}
