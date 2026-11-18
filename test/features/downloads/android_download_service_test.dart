import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/l10n/app_localizations.dart';
import 'package:strumok/features/downloads/data/android_download_service.dart';
import 'package:strumok/features/downloads/data/android_download_task.dart';
import 'package:strumok/features/downloads/data/download_engine.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';

import '../../helpers/fake_downloads.dart';

/// Runs the "service isolate" ([DownloadServiceHost]) in-process, as `flutter_foreground_task` would.
class FakeForegroundTaskApi implements ForegroundTaskApi {
  final DownloadQueueStore store;
  final FakeRunner runner;
  final listeners = <void Function(Object data)>[];
  final notifications = <(String, String)>[];
  DownloadServiceHost? host;
  var starts = 0;

  /// Simulates a service that is stopping: messages are dropped and it is gone right after.
  var dropMessages = false;

  FakeForegroundTaskApi(this.store, this.runner);

  @override
  Future<bool> get isRunning async => host != null;

  @override
  Future<bool> start() async {
    starts++;
    final host = this.host = DownloadServiceHost(
      engine: DownloadEngine(store: store, runner: runner),
      l10n: lookupAppLocalizations(const Locale('en')),
      stopDelay: Duration.zero,
      sendToApp: (message) {
        for (final listener in [...listeners]) {
          listener(message);
        }
      },
      updateNotification: (title, text) => notifications.add((title, text)),
      // Like the plugin: the service counts as running until it is destroyed.
      stop: () async {
        await this.host?.dispose();
        this.host = null;
      },
    );
    await host.start();
    return true;
  }

  @override
  void send(String message) {
    if (dropMessages) {
      final current = host;
      host = null;
      unawaited(current?.dispose());
      return;
    }
    host?.onMessage(message);
  }

  @override
  void addListener(void Function(Object data) listener) => listeners.add(listener);

  @override
  void removeListener(void Function(Object data) listener) => listeners.remove(listener);
}

void main() {
  late Directory dir;
  late DownloadQueueStore store;
  late FakeRunner runner;
  late FakeForegroundTaskApi api;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('android_service');
    store = DownloadQueueStore(File('${dir.path}/queue.json'));
    runner = FakeRunner();
    api = FakeForegroundTaskApi(store, runner);
  });

  tearDown(() async {
    await api.host?.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<AndroidDownloadService> createService() => AndroidDownloadService.create(api: api, store: store);

  test('a command while the service is stopped is saved and starts the service, which runs it', () async {
    final app = await createService();
    expect(api.starts, 0, reason: 'nothing to do yet');

    await app.send(EnqueueDownloads([downloadRequest('show', 0), downloadRequest('show', 1)]));
    expect(api.starts, 1);
    await pumpEventQueue();
    expect(runner.started, ['alpha_show_0']);
    expect(app.queue['alpha_show_0']!.state, DownloadState.started, reason: 'the service streams its queue');
    expect(api.notifications.last.$1, 'Downloading 2 items');
  });

  test('commands to a running service are acknowledged; it stops itself when the queue is done', () async {
    final app = await createService();
    await app.send(EnqueueDownloads([downloadRequest('a', 0)]));
    await pumpEventQueue();

    await app.send(EnqueueDownloads([downloadRequest('b', 0)]));
    expect(app.queue.tasks.map((t) => t.id), ['alpha_a_0', 'alpha_b_0']);
    expect(api.starts, 1, reason: 'delivered to the running service');

    await app.send(const CancelDownload('alpha_b_0'));
    expect(app.queue['alpha_b_0']!.state, DownloadState.canceled);

    runner.complete('alpha_a_0');
    for (var i = 0; i < 20 && api.host != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(app.queue['alpha_a_0']!.state, DownloadState.completed);
    expect(api.host, isNull, reason: 'idle service stopped');
    expect(api.notifications.last.$1, 'Downloads finished');

    // Stopped again: the next command goes to the file and restarts the service.
    await app.send(const RetryDownload('alpha_b_0'));
    expect(api.starts, 2);
    await pumpEventQueue();
    expect(runner.started.last, 'alpha_b_0');
  });

  test('unfinished tasks of an earlier run restart the service when the app starts', () async {
    await store.save(
      DownloadQueue(
        tasks: [
          DownloadTask(request: downloadRequest('a', 0), sequence: 0, state: DownloadState.started, progress: 0.3),
        ],
        nextSequence: 1,
      ),
    );
    final app = await createService();
    expect(api.starts, 1);
    await pumpEventQueue();
    expect(runner.started, ['alpha_a_0']);
    expect(app.queue['alpha_a_0']!.progress, 0.3);
  });

  test('an app opened while the service runs asks for its queue', () async {
    await api.start();
    api.host!.engine.apply(EnqueueDownloads([downloadRequest('a', 0)]));
    final app = await createService();
    expect(app.queue['alpha_a_0']!.state, DownloadState.started);
    expect(api.starts, 1);
  });

  test('a command lost by a stopping service is applied to the file instead', () async {
    final app = await createService();
    await app.send(EnqueueDownloads([downloadRequest('a', 0)]));
    await pumpEventQueue();
    api.dropMessages = true;

    final sent = app.send(EnqueueDownloads([downloadRequest('b', 0)]));
    await sent.timeout(AndroidDownloadService.ackTimeout + const Duration(seconds: 2));
    expect((await store.load()).tasks.map((t) => t.id), containsAll(['alpha_a_0', 'alpha_b_0']));
    expect(api.starts, 2, reason: 'work pending: the service is started again');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('notification texts', () {
    final l10n = lookupAppLocalizations(const Locale('uk'));
    var queue = const DownloadQueue().apply(
      EnqueueDownloads([downloadRequest('Show', 0), downloadRequest('Movie', 0)]),
    );
    expect(downloadNotificationText(l10n, queue), ('Завантаження: 2', ''));
    queue = queue.update('alpha_Show_0', (t) => t.copyWith(state: DownloadState.started, progress: 0.42));
    expect(downloadNotificationText(l10n, queue), ('Завантаження: 2', 'Show · 0 — 42%'));
    expect(downloadNotificationText(l10n, const DownloadQueue()).$1, 'Завантаження завершено');
  });
}
