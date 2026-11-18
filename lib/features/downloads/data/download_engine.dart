import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../../../core/network/file_downloader.dart';
import '../domain/download_queue.dart';
import '../domain/download_task.dart';
import 'download_resolver.dart';
import 'media_download_runner.dart';

final _log = Logger('DownloadEngine');

/// The queue file (`<support>/downloads/queue.json`); writes are atomic (temp file + rename) and serialized. Temp
/// names are unique: the app and the Android service isolate may write at the same time.
class DownloadQueueStore {
  final File file;
  Future<void> _writes = Future.value();
  int _temp = 0;

  DownloadQueueStore(this.file);

  /// Completes when every save issued so far is on disk.
  Future<void> get flushed => _writes;

  Future<DownloadQueue> load() async {
    try {
      if (!file.existsSync()) return const DownloadQueue();
      return DownloadQueue.fromJson(jsonDecode(await file.readAsString()) as Map<String, Object?>);
    } catch (e) {
      _log.warning('Download queue unreadable, starting empty', e);
      return const DownloadQueue();
    }
  }

  Future<void> save(DownloadQueue queue) {
    final json = jsonEncode(queue.toJson());
    return _writes = _writes.then((_) async {
      try {
        await file.parent.create(recursive: true);
        final temp = File('${file.path}.${pid}_${_temp++}.tmp');
        await temp.writeAsString(json, flush: true);
        await temp.rename(file.path);
      } catch (e) {
        _log.warning('Download queue not saved', e);
      }
    });
  }
}

/// Runs the download queue (spec-08 §8.1): starts what the scheduler picks, reports throttled progress and speed,
/// persists every state change so unfinished tasks resume after a restart.
class DownloadEngine {
  final DownloadQueueStore store;
  final DownloadTaskRunner runner;
  final Duration progressInterval;
  final DateTime Function() clock;

  final _changes = StreamController<DownloadQueue>.broadcast(sync: true);
  final _running = <String, DownloadCancelToken>{};
  final _jobs = <String, Future<void>>{};
  DownloadQueue _queue = const DownloadQueue();
  bool _started = false;
  bool _disposed = false;

  DownloadEngine({
    required this.store,
    required this.runner,
    this.progressInterval = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  DownloadQueue get queue => _queue;

  Stream<DownloadQueue> get changes => _changes.stream;

  /// Loads the persisted queue (running tasks become queued again) and starts runnable tasks.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _queue = (await store.load()).resumed();
    _schedule();
    _publish(save: true);
  }

  void apply(DownloadCommand command) {
    if (_disposed) return;
    _queue = _queue.apply(command);
    // Canceled (or dismissed) tasks stop their downloads; partial files are kept for a later retry.
    for (final id in _running.keys.toList()) {
      if (_queue[id]?.state != DownloadState.started) _running.remove(id)?.cancel();
    }
    _schedule();
    _publish(save: true);
  }

  /// Completes when nothing is queued or running (tests and the Android service's auto-stop).
  Future<void> whenIdle() async {
    while (!_queue.idle || _jobs.isNotEmpty) {
      await Future.wait(_jobs.values.toList());
      if (_jobs.isEmpty && !_queue.idle) await changes.first;
    }
  }

  /// Stops running downloads without changing their state, so they resume on the next start. An idle queue is not
  /// written again: every change was saved already, and a late write could hide what the app saved since.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final token in _running.values) {
      token.cancel();
    }
    await Future.wait(_jobs.values.toList());
    if (!_queue.idle) unawaited(store.save(_queue));
    await store.flushed;
    await _changes.close();
  }

  void _schedule() {
    if (_disposed || !_started) return;
    for (final task in _queue.runnable()) {
      final token = DownloadCancelToken();
      _running[task.id] = token;
      _queue = _queue.update(task.id, (t) => t.copyWith(state: DownloadState.started, speed: 0, clearFailure: true));
      // Block body: returning the removed future from whenComplete would make the job wait on itself.
      _jobs[task.id] = _run(task, token).whenComplete(() {
        _jobs.remove(task.id);
      });
    }
  }

  Future<void> _run(DownloadTask task, DownloadCancelToken token) async {
    var lastAt = clock();
    var lastBytes = 0;

    void onProgress(double progress, int bytes) {
      if (_disposed || token.isCanceled) return;
      final now = clock();
      final elapsed = now.difference(lastAt);
      if (elapsed < progressInterval && progress < 1) return;
      final speed = elapsed.inMilliseconds <= 0 ? 0 : ((bytes - lastBytes) * 1000 / elapsed.inMilliseconds).round();
      lastAt = now;
      lastBytes = bytes;
      _queue = _queue.update(task.id, (t) => t.copyWith(progress: progress, speed: speed < 0 ? 0 : speed));
      _publish();
    }

    DownloadState state;
    DownloadFailure? failure;
    try {
      await runner.run(task.request, onProgress: onProgress, cancelToken: token);
      state = DownloadState.completed;
    } on DownloadCanceledException {
      state = DownloadState.canceled;
    } catch (e, st) {
      failure = classifyDownloadError(e);
      _log.warning('${task.id} failed (${failure.name})', e, st);
      state = DownloadState.failed;
    }
    _running.remove(task.id);
    // Disposing leaves the task started (it resumes later); a cancel already set the state.
    if (_disposed || _queue[task.id]?.state != DownloadState.started) return;
    _queue = _queue.update(
      task.id,
      (t) => t.copyWith(
        state: state,
        speed: 0,
        progress: state == DownloadState.completed ? 1 : t.progress,
        failure: failure,
      ),
    );
    _schedule();
    _publish(save: true);
  }

  void _publish({bool save = false}) {
    if (_disposed) return;
    if (save) unawaited(store.save(_queue));
    _changes.add(_queue);
  }
}
