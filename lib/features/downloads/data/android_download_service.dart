import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logging/logging.dart';

import '../domain/download_queue.dart';
import 'download_engine.dart';
import 'download_service.dart';

final _log = Logger('AndroidDownloadService');

/// Messages between the app and the download service isolate; JSON strings, so nested maps survive the channel.
abstract final class DownloadServiceMessages {
  static String hello() => jsonEncode({'type': 'hello'});

  static String command(int seq, DownloadCommand command) =>
      jsonEncode({'type': 'command', 'seq': seq, 'command': command.toJson()});

  static String queue(DownloadQueue queue, {int? ack}) =>
      jsonEncode({'type': 'queue', 'queue': queue.toJson(), 'ack': ack});

  static Map<String, Object?>? decode(Object data) {
    try {
      return data is String ? (jsonDecode(data) as Map).cast<String, Object?>() : null;
    } catch (e) {
      _log.warning('Malformed download service message', e);
      return null;
    }
  }
}

/// The plugin's static API, behind an interface for tests.
abstract interface class ForegroundTaskApi {
  Future<bool> get isRunning;

  /// Starts the service isolate; false when Android refused.
  Future<bool> start();

  void send(String message);

  void addListener(void Function(Object data) listener);

  void removeListener(void Function(Object data) listener);
}

/// App side of the Android download service (spec-08 §8.1): the engine runs in the foreground service's own isolate,
/// so downloads continue when the app is in the background or closed. While the service runs it owns the queue and
/// streams it here; when it is stopped, commands are applied to the queue file directly and the service is started
/// whenever there is work to do.
class AndroidDownloadService implements DownloadService {
  static const ackTimeout = Duration(seconds: 3);

  final ForegroundTaskApi api;
  final DownloadQueueStore store;
  final _changes = StreamController<DownloadQueue>.broadcast(sync: true);
  final _acks = <int, Completer<void>>{};
  DownloadQueue _queue = const DownloadQueue();
  int _seq = 0;
  Future<void> _sending = Future.value();

  AndroidDownloadService._(this.api, this.store);

  static Future<AndroidDownloadService> create({
    required ForegroundTaskApi api,
    required DownloadQueueStore store,
  }) async {
    final service = AndroidDownloadService._(api, store);
    await service._init();
    return service;
  }

  @override
  DownloadQueue get queue => _queue;

  @override
  Stream<DownloadQueue> get changes => _changes.stream;

  Future<void> _init() async {
    api.addListener(_onData);
    _queue = (await store.load()).resumed();
    if (await api.isRunning) {
      api.send(DownloadServiceMessages.hello());
    } else if (!_queue.idle) {
      // Unfinished downloads of an earlier run resume (spec-08 §8.1).
      await _start();
    }
    _emit();
  }

  @override
  Future<void> send(DownloadCommand command) =>
      _sending = _sending.then((_) => _send(command), onError: (_) => _send(command));

  Future<void> _send(DownloadCommand command) async {
    if (await api.isRunning) {
      final seq = ++_seq;
      final ack = _acks[seq] = Completer<void>();
      api.send(DownloadServiceMessages.command(seq, command));
      try {
        return await ack.future.timeout(ackTimeout);
      } on TimeoutException {
        // The service may have been stopping; when it is gone the command is applied here instead.
        if (await api.isRunning) return;
      } finally {
        _acks.remove(seq);
      }
    }
    // The app's copy is fed every change by the service, so it is never older than the file (whose last writes
    // may still be landing while the service stops).
    _queue = _queue.resumed().apply(command);
    await store.save(_queue);
    _emit();
    if (!_queue.idle) await _start();
  }

  Future<void> _start() async {
    if (!await api.start()) _log.warning('Download service did not start');
  }

  void _onData(Object data) {
    final message = DownloadServiceMessages.decode(data);
    if (message == null || message['type'] != 'queue') return;
    _queue = DownloadQueue.fromJson((message['queue'] as Map).cast<String, Object?>());
    _emit();
    final ack = message['ack'];
    if (ack is int) _acks[ack]?.complete();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(_queue);
  }

  @override
  Future<void> dispose() async {
    api.removeListener(_onData);
    await _changes.close();
  }
}

/// [ForegroundTaskApi] over `flutter_foreground_task`.
class PluginForegroundTaskApi implements ForegroundTaskApi {
  static const serviceId = 4301;
  static const cancelAllButton = 'cancelAll';

  /// Localized notification texts at the time the service starts; the service isolate updates them afterwards.
  final ({String title, String cancelAll}) Function() labels;
  final void Function() callback;

  PluginForegroundTaskApi({required this.labels, required this.callback});

  /// Once per app run, before the first [start].
  static void initialize({required String channelName}) => FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'downloads',
      channelName: channelName,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      allowWifiLock: true,
      // Downloads go on after the app is swiped away; the service stops itself when the queue is done.
      stopWithTask: false,
    ),
  );

  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  @override
  Future<bool> start() async {
    final labels = this.labels();
    final result = await FlutterForegroundTask.startService(
      serviceId: serviceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: labels.title,
      notificationText: '',
      notificationButtons: [NotificationButton(id: cancelAllButton, text: labels.cancelAll)],
      callback: callback,
    );
    if (result is ServiceRequestFailure) _log.warning('startService failed', result.error);
    return result is ServiceRequestSuccess;
  }

  @override
  void send(String message) => FlutterForegroundTask.sendDataToTask(message);

  @override
  void addListener(void Function(Object data) listener) => FlutterForegroundTask.addTaskDataCallback(listener);

  @override
  void removeListener(void Function(Object data) listener) => FlutterForegroundTask.removeTaskDataCallback(listener);
}
