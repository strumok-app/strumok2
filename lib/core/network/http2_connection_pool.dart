import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http2/transport.dart';

/// The server did not select `h2` via ALPN; the origin must be used over HTTP/1.1.
class Http2NotNegotiated implements Exception {
  const Http2NotNegotiated();

  @override
  String toString() => 'Server did not negotiate HTTP/2';
}

typedef SecureSocketConnector = Future<SecureSocket> Function(String host, int port);

/// HTTP/2 connections to one origin (`host:port`). Requests are multiplexed onto an open connection with a free
/// stream slot (bounded by the server's `SETTINGS_MAX_CONCURRENT_STREAMS`); another connection is dialed when all are
/// full. Connections closed by the peer (GOAWAY, socket end) are never handed out again; idle ones close after
/// [idleTimeout].
class Http2OriginPool {
  final String host;
  final int port;
  final SecureSocketConnector connect;
  final int maxStreamsPerConnection;
  final Duration settingsTimeout;
  final Duration idleTimeout;

  final _connections = <Http2PooledConnection>[];
  Future<Http2PooledConnection>? _dialing;
  bool _closed = false;

  Http2OriginPool({
    required this.host,
    required this.port,
    required this.connect,
    this.maxStreamsPerConnection = 100,
    this.settingsTimeout = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 90),
  });

  int get connectionCount => _connections.length;

  /// Claims a stream slot; the caller must [Http2Lease.release] it once the stream ends.
  /// Throws [Http2NotNegotiated] when the server only speaks HTTP/1.1.
  Future<Http2Lease> acquire() async {
    while (true) {
      if (_closed) throw http.ClientException('HTTP client is closed');
      final available = _connections.where((c) => c.hasCapacity).firstOrNull;
      if (available != null) return available._lease();
      final connection = await (_dialing ??= _dial().whenComplete(() => _dialing = null));
      if (connection.hasCapacity) return connection._lease();
      if (!connection.isOpen) throw http.ClientException('HTTP/2 connection to $host:$port was closed');
    }
  }

  /// Closes every connection, cancelling in-flight streams.
  void close() {
    _closed = true;
    for (final connection in _connections.toList()) {
      connection._close(force: true);
    }
  }

  Future<Http2PooledConnection> _dial() async {
    final socket = await connect(host, port);
    if (socket.selectedProtocol != 'h2') {
      socket.destroy();
      throw const Http2NotNegotiated();
    }
    socket.setOption(SocketOption.tcpNoDelay, true);

    final died = Completer<void>();
    final incoming = socket.transform(
      StreamTransformer<Uint8List, List<int>>.fromHandlers(
        handleDone: (sink) {
          if (!died.isCompleted) died.complete();
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          if (!died.isCompleted) died.complete();
          sink.addError(error, stackTrace);
        },
      ),
    );
    final transport = ClientTransportConnection.viaStreams(incoming, _SocketSink(socket));
    final connection = Http2PooledConnection._(this, transport);
    unawaited(died.future.then((_) => connection._onSocketClosed()));

    // The peer's stream limit arrives in its initial SETTINGS frame; wait for it (bounded) before multiplexing.
    try {
      await Future.any([
        transport.onInitialPeerSettingsReceived,
        died.future.then<void>((_) => throw http.ClientException('HTTP/2 connection to $host:$port closed early')),
      ]).timeout(settingsTimeout);
    } catch (_) {
      unawaited(transport.terminate().catchError((Object _) {}));
      rethrow;
    }
    if (_closed) {
      unawaited(transport.terminate().catchError((Object _) {}));
      throw http.ClientException('HTTP client is closed');
    }
    _connections.add(connection);
    return connection;
  }
}

class Http2PooledConnection {
  final Http2OriginPool _pool;
  final ClientTransportConnection transport;
  int _active = 0;
  bool _closed = false;
  Timer? _idleTimer;

  Http2PooledConnection._(this._pool, this.transport);

  bool get isOpen => !_closed && transport.isOpen;

  bool get hasCapacity {
    final peerLimit = transport.peerMaxConcurrentStreams;
    final capacity = peerLimit == null
        ? _pool.maxStreamsPerConnection
        : max(1, min(_pool.maxStreamsPerConnection, peerLimit));
    return isOpen && _active < capacity;
  }

  Http2Lease _lease() {
    _active++;
    _idleTimer?.cancel();
    _idleTimer = null;
    return Http2Lease._(this);
  }

  void _release() {
    _active--;
    if (_active > 0) return;
    if (isOpen) {
      _idleTimer = Timer(_pool.idleTimeout, _close);
    } else {
      _close();
    }
  }

  void _close({bool force = false}) {
    _idleTimer?.cancel();
    if (_closed) return;
    _closed = true;
    _pool._connections.remove(this);
    final done = force ? transport.terminate() : transport.finish();
    unawaited(done.catchError((Object _) {}));
  }

  void _onSocketClosed() {
    _idleTimer?.cancel();
    _closed = true;
    _pool._connections.remove(this);
  }
}

/// One stream slot on a pooled connection.
class Http2Lease {
  final Http2PooledConnection connection;
  bool _released = false;

  Http2Lease._(this.connection);

  ClientTransportConnection get transport => connection.transport;

  void release() {
    if (_released) return;
    _released = true;
    connection._release();
  }
}

/// Socket sink whose `close`/`done` never surface errors: the http2 writer awaits them without handlers, and a broken
/// socket is already reported through the incoming side.
class _SocketSink implements StreamSink<List<int>> {
  final Socket _socket;

  _SocketSink(this._socket);

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream).catchError((Object _) {});

  @override
  Future<void> close() => _socket.close().catchError((Object _) {});

  @override
  Future<void> get done => _socket.done.catchError((Object _) {});
}
