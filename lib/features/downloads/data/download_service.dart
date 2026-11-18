import 'dart:async';

import '../domain/download_queue.dart';
import 'download_engine.dart';

/// The download manager as the app sees it (spec-08 §8.1): in-process on desktop, a foreground service on Android.
abstract interface class DownloadService {
  DownloadQueue get queue;

  /// Every change of [queue], including throttled progress.
  Stream<DownloadQueue> get changes;

  Future<void> send(DownloadCommand command);

  Future<void> dispose();
}

/// Desktop (and tests): the engine runs in the app isolate; downloads are async IO, so the UI stays responsive.
class InProcessDownloadService implements DownloadService {
  final DownloadEngine engine;

  InProcessDownloadService(this.engine);

  static Future<InProcessDownloadService> start(DownloadEngine engine) async {
    await engine.start();
    return InProcessDownloadService(engine);
  }

  @override
  DownloadQueue get queue => engine.queue;

  @override
  Stream<DownloadQueue> get changes => engine.changes;

  @override
  Future<void> send(DownloadCommand command) async => engine.apply(command);

  @override
  Future<void> dispose() => engine.dispose();
}
