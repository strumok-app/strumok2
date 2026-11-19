import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/network/http_client.dart';
import 'package:strumok/features/downloads/data/download_engine.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';

import '../../helpers/fake_downloads.dart';

void main() {
  late Directory dir;
  late DownloadQueueStore store;
  late FakeRunner runner;
  late DateTime now;
  late DownloadEngine engine;

  DownloadEngine createEngine() =>
      DownloadEngine(store: store, runner: runner, clock: () => now, progressInterval: const Duration(seconds: 1));

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('engine');
    store = DownloadQueueStore(File('${dir.path}/downloads/queue.json'));
    runner = FakeRunner();
    now = DateTime(2026);
    engine = createEngine();
    await engine.start();
  });

  tearDown(() async {
    await engine.dispose();
    dir.deleteSync(recursive: true);
  });

  DownloadState state(String id) => engine.queue[id]!.state;

  Future<void> settle() => pumpEventQueue();

  test('runs tasks, then the next episode of the same show', () async {
    engine.apply(
      EnqueueDownloads([downloadRequest('show', 0), downloadRequest('show', 1), downloadRequest('movie', 0)]),
    );
    expect(runner.started, ['alpha_show_0', 'alpha_movie_0']);
    expect(state('alpha_show_1'), DownloadState.queued);

    runner.complete('alpha_show_0');
    await settle();
    expect(state('alpha_show_0'), DownloadState.completed);
    expect(engine.queue['alpha_show_0']!.progress, 1);
    expect(runner.started.last, 'alpha_show_1');
  });

  test('failures are classified and do not block the group', () async {
    engine.apply(EnqueueDownloads([downloadRequest('show', 0), downloadRequest('show', 1)]));
    runner.fail('alpha_show_0', HttpStatusException(Uri(), 404));
    await settle();
    expect(state('alpha_show_0'), DownloadState.failed);
    expect(engine.queue['alpha_show_0']!.failure, DownloadFailure.unavailable);
    expect(state('alpha_show_1'), DownloadState.started);
  });

  test('cancel aborts the running download and starts the next task', () async {
    engine.apply(const SetMaxConcurrentDownloads(1));
    engine.apply(EnqueueDownloads([downloadRequest('a', 0), downloadRequest('b', 0)]));
    engine.apply(const CancelDownload('alpha_a_0'));
    expect(runner.runs['alpha_a_0']!.token.isCanceled, isTrue);
    await settle();
    expect(state('alpha_a_0'), DownloadState.canceled);
    expect(state('alpha_b_0'), DownloadState.started);

    engine.apply(const RetryDownload('alpha_a_0'));
    runner.complete('alpha_b_0');
    await settle();
    expect(runner.started, ['alpha_a_0', 'alpha_b_0', 'alpha_a_0']);
  });

  test('progress is throttled and reports speed', () async {
    final updates = <(double, int)>[];
    final sub = engine.changes.listen((q) {
      final t = q['alpha_a_0'];
      if (t != null && t.state == DownloadState.started) updates.add((t.progress, t.speed));
    });
    engine.apply(EnqueueDownloads([downloadRequest('a', 0)]));
    updates.clear();
    final report = runner.runs['alpha_a_0']!.progress;

    now = now.add(const Duration(milliseconds: 300));
    report(0.1, 300);
    expect(updates, isEmpty, reason: 'within the interval');

    now = now.add(const Duration(milliseconds: 700));
    report(0.2, 1000);
    expect(updates, [(0.2, 1000)]);

    now = now.add(const Duration(seconds: 2));
    report(0.6, 5000);
    expect(updates.last, (0.6, 2000));
    await sub.cancel();
  });

  test('state survives a restart; running tasks resume', () async {
    engine.apply(EnqueueDownloads([downloadRequest('a', 0), downloadRequest('b', 0)]));
    runner.complete('alpha_b_0');
    await settle();
    await engine.dispose();
    expect(runner.runs['alpha_a_0']!.token.isCanceled, isTrue);

    runner = FakeRunner();
    engine = createEngine();
    await engine.start();
    expect(engine.queue.tasks.map((t) => t.id), ['alpha_a_0'], reason: 'completed tasks are dropped');
    expect(runner.started, ['alpha_a_0']);
  });

  test('raising the limit starts more tasks; whenIdle waits for all', () async {
    engine.apply(const SetMaxConcurrentDownloads(1));
    engine.apply(EnqueueDownloads([downloadRequest('a', 0), downloadRequest('b', 0), downloadRequest('c', 0)]));
    expect(runner.started, hasLength(1));
    engine.apply(const SetMaxConcurrentDownloads(3));
    expect(runner.started, hasLength(3));

    var idle = false;
    final whenIdle = engine.whenIdle().then((_) => idle = true);
    runner.complete('alpha_a_0');
    runner.complete('alpha_b_0');
    await settle();
    expect(idle, isFalse);
    runner.complete('alpha_c_0');
    await whenIdle;
    expect(idle, isTrue);
    await store.flushed;
    expect((await store.load()).tasks.every((t) => t.state == DownloadState.completed), isTrue);
  });

  test('an unreadable queue file starts empty', () async {
    await engine.dispose();
    store.file.writeAsStringSync('{not json');
    engine = createEngine();
    await engine.start();
    expect(engine.queue, const DownloadQueue());
  });
}
