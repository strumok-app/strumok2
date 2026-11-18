import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/network/http_client.dart';
import '../../../core/platform/app_paths.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/storage/app_preferences.dart';
import '../../suppliers/data/supplier_bundle_installer.dart';
import '../../suppliers/data/supplier_registry.dart';
import '../domain/download_queue.dart';
import '../domain/download_task.dart';
import 'android_download_service.dart';
import 'download_engine.dart';
import 'download_resolver.dart';
import 'media_download_runner.dart';

final _log = Logger('DownloadServiceIsolate');

/// Entry point of the Android download service isolate (spec-08 §8.1).
@pragma('vm:entry-point')
void downloadServiceMain() => FlutterForegroundTask.setTaskHandler(DownloadTaskHandler());

/// Service-side logic without the plugin: answers the app, reports the queue, keeps the notification current and
/// stops the service shortly after the queue becomes idle (a grace period lets new commands keep it alive).
class DownloadServiceHost {
  static const notificationInterval = Duration(seconds: 1);

  final DownloadEngine engine;
  final void Function(String message) sendToApp;
  final void Function(String title, String text) updateNotification;
  final Future<void> Function() stop;
  final AppLocalizations l10n;
  final DateTime Function() clock;
  final Duration stopDelay;

  StreamSubscription<DownloadQueue>? _subscription;
  Timer? _stopTimer;
  DateTime? _notifiedAt;
  int _notifiedActive = -1;
  int? _pendingAck;

  DownloadServiceHost({
    required this.engine,
    required this.sendToApp,
    required this.updateNotification,
    required this.stop,
    required this.l10n,
    DateTime Function()? clock,
    this.stopDelay = const Duration(seconds: 3),
  }) : clock = clock ?? DateTime.now;

  Future<void> start() async {
    _subscription = engine.changes.listen(_onQueue);
    await engine.start();
    _onQueue(engine.queue);
  }

  void onMessage(Object data) {
    final message = DownloadServiceMessages.decode(data);
    switch (message?['type']) {
      case 'hello':
        sendToApp(DownloadServiceMessages.queue(engine.queue));
      case 'command':
        _pendingAck = message!['seq'] as int?;
        engine.apply(DownloadCommand.fromJson((message['command'] as Map).cast<String, Object?>()));
        // A command that changes nothing still needs its acknowledgement.
        if (_pendingAck != null) _onQueue(engine.queue);
    }
  }

  void cancelAll() => engine.apply(const CancelAllDownloads());

  Future<void> dispose() async {
    _stopTimer?.cancel();
    await _subscription?.cancel();
    await engine.dispose();
  }

  void _onQueue(DownloadQueue queue) {
    final ack = _pendingAck;
    _pendingAck = null;
    sendToApp(DownloadServiceMessages.queue(queue, ack: ack));
    _notify(queue);
    if (queue.idle) {
      _stopTimer ??= Timer(stopDelay, () => unawaited(stop()));
    } else {
      _stopTimer?.cancel();
      _stopTimer = null;
    }
  }

  void _notify(DownloadQueue queue) {
    final now = clock();
    final active = queue.tasks.where((t) => t.state.active).toList();
    final countChanged = active.length != _notifiedActive;
    if (!countChanged && _notifiedAt != null && now.difference(_notifiedAt!) < notificationInterval) return;
    _notifiedAt = now;
    _notifiedActive = active.length;
    final (title, text) = downloadNotificationText(l10n, queue);
    updateNotification(title, text);
  }
}

/// Title and text of the progress notification.
(String, String) downloadNotificationText(AppLocalizations l10n, DownloadQueue queue) {
  final active = queue.tasks.where((t) => t.state.active).toList();
  final running = queue.tasks.where((t) => t.state == DownloadState.started).toList();
  if (active.isEmpty) return (l10n.downloadsNotificationDone, '');
  final title = l10n.downloadsNotificationActive(active.length);
  if (running.isEmpty) return (title, '');
  final task = running.first;
  final name = task.request.itemTitle.isEmpty
      ? task.request.title
      : '${task.request.title} · ${task.request.itemTitle}';
  return (title, l10n.downloadsNotificationProgress(name, (task.progress * 100).round()));
}

/// Wires [DownloadServiceHost] to the plugin; everything else (prefs, paths, HTTP client, supplier bundle) is created
/// in this isolate. The supplier bundle is loaded only when a task needs links.
class DownloadTaskHandler extends TaskHandler {
  DownloadServiceHost? _host;
  http.Client? _client;
  Future<SupplierBundleState>? _bundle;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
    Logger.root.onRecord.listen(
      (r) => debugPrint('[downloads] ${r.level.name} ${r.loggerName}: ${r.message} ${r.error ?? ''}'),
    );

    final (prefs, paths, info) = await (AppPreferences.create(), AppPaths.resolve(), PackageInfo.fromPlatform()).wait;
    final client = _client = await createHttpClient(appVersion: info.version);
    final installer = SupplierBundleInstaller(
      client: client,
      directory: paths.ffi,
      platform: AppPlatform.android,
      downloadKey: null,
    );
    final resolver = SupplierDownloadResolver((name) async {
      final state = await (_bundle ??= loadInitialSupplierBundle(prefs: prefs, installer: installer));
      return switch (state) {
        SupplierBundleReady(:final bundle) => bundle.suppliers.where((s) => s.name == name).firstOrNull,
        SupplierBundleMissing() => null,
      };
    });
    final language = prefs.getString(AppPreferences.userLanguage);
    final locale = AppLocalizations.supportedLocales.where((l) => l.languageCode == language).firstOrNull;

    final host = _host = DownloadServiceHost(
      engine: DownloadEngine(
        store: DownloadQueueStore(paths.downloadQueue),
        runner: MediaDownloadRunner(client: client, resolver: resolver),
      ),
      l10n: lookupAppLocalizations(locale ?? const Locale('uk')),
      sendToApp: FlutterForegroundTask.sendDataToMain,
      updateNotification: (title, text) =>
          unawaited(FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text)),
      stop: () async {
        _log.info('Queue done, stopping the download service');
        await FlutterForegroundTask.stopService();
      },
    );
    await host.start();
  }

  @override
  void onReceiveData(Object data) => _host?.onMessage(data);

  @override
  void onNotificationButtonPressed(String id) {
    if (id == PluginForegroundTaskApi.cancelAllButton) _host?.cancelAll();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Android 15 limits dataSync services to 6 h a day; unfinished tasks resume with the next start.
    if (isTimeout) _log.info('Download service timed out');
    await _host?.dispose();
    _client?.close();
  }
}
