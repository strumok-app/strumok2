import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'single_instance.g.dart';

final _log = Logger('SingleInstance');

/// Takes the exclusive lock of [file] without waiting; false when another process holds it.
typedef InstanceLocker = Future<bool> Function(RandomAccessFile file);

Future<bool> _lockExclusive(RandomAccessFile file) async {
  try {
    await file.lock(FileLock.exclusive);
    return true;
  } on FileSystemException {
    return false;
  }
}

/// One app instance per user on desktop: two instances would share (and lock) the same profile data, e.g. the
/// Firebase session store. The first instance holds an OS file lock in the app support folder and listens on a
/// loopback port; a second instance asks it to come to the front and quits. The lock goes with the process, so a
/// crashed instance never blocks the next start.
class SingleInstance {
  static const lockFileName = 'instance.lock';
  static const infoFileName = 'instance.json';
  static const _activate = 'activate';

  final RandomAccessFile _lock;
  final ServerSocket _server;
  final _activations = StreamController<void>.broadcast();
  var _pending = 0;

  SingleInstance._(this._lock, this._server) {
    _server.listen((socket) {
      unawaited(
        utf8.decoder
            .bind(socket)
            .join()
            .then((message) {
              if (message.trim() != _activate) return;
              _activations.hasListener ? _activations.add(null) : _pending++;
            })
            .catchError((Object e) => _log.fine('Bad activation request', e))
            .whenComplete(socket.destroy),
      );
    });
  }

  /// Other instances asking to show this one. Requests that came before the first listener are replayed to it.
  Stream<void> get activations async* {
    for (; _pending > 0; _pending--) {
      yield null;
    }
    yield* _activations.stream;
  }

  /// Returns the instance to keep for the app's lifetime, or null when another instance runs (it was asked to come
  /// to the front; this one should quit).
  static Future<SingleInstance?> acquire(Directory dir, {InstanceLocker lock = _lockExclusive, int? processId}) async {
    final ownPid = processId ?? pid;
    await dir.create(recursive: true);
    final info = File(p.join(dir.path, infoFileName));
    final file = await File(p.join(dir.path, lockFileName)).open(mode: FileMode.append);

    if (!await lock(file)) {
      final other = await _readInfo(info);
      // Hot restart runs main() again in the process that already holds the lock.
      if (other?.pid != ownPid) {
        await file.close();
        await _activateOther(other?.port);
        return null;
      }
    }
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    await info.writeAsString(jsonEncode({'pid': ownPid, 'port': server.port}), flush: true);
    return SingleInstance._(file, server);
  }

  Future<void> dispose() async {
    await _server.close();
    await _activations.close();
    await _lock.close();
  }

  static Future<({int pid, int port})?> _readInfo(File info) async {
    try {
      final json = jsonDecode(await info.readAsString()) as Map<String, Object?>;
      return (pid: (json['pid'] as num).toInt(), port: (json['port'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  static Future<void> _activateOther(int? port) async {
    if (port == null) return;
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 2));
      socket.write(_activate);
      await socket.flush();
      await socket.close();
    } catch (e) {
      _log.info('Running instance did not answer the activation request', e);
    }
  }
}

/// Brings the window of this (first) instance to the front when another one was started.
Future<void> bringWindowToFront() async {
  if (await windowManager.isMinimized()) await windowManager.restore();
  await windowManager.show();
  await windowManager.focus();
}

/// The lock of the running desktop instance; null on Android (the system keeps one activity task).
@Riverpod(keepAlive: true)
SingleInstance? singleInstance(Ref ref) => null;
