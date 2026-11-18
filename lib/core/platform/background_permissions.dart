import 'package:file_selector/file_selector.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_platform.dart';

part 'background_permissions.g.dart';

/// What background downloads need from the system (spec-08 §8.1): the progress notification and, politely asked,
/// an exemption from battery optimization so Android does not stop the service.
abstract interface class BackgroundPermissions {
  /// Whether asking for [requestBatteryExemption] makes sense (Android, not exempt yet).
  Future<bool> get canRequestBatteryExemption;

  Future<void> requestNotifications();

  Future<void> requestBatteryExemption();
}

class AndroidBackgroundPermissions implements BackgroundPermissions {
  const AndroidBackgroundPermissions();

  @override
  Future<bool> get canRequestBatteryExemption async => !await FlutterForegroundTask.isIgnoringBatteryOptimizations;

  @override
  Future<void> requestNotifications() async {
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  @override
  Future<void> requestBatteryExemption() => FlutterForegroundTask.requestIgnoreBatteryOptimization();
}

class NoBackgroundPermissions implements BackgroundPermissions {
  const NoBackgroundPermissions();

  @override
  Future<bool> get canRequestBatteryExemption async => false;

  @override
  Future<void> requestNotifications() async {}

  @override
  Future<void> requestBatteryExemption() async {}
}

@Riverpod(keepAlive: true)
BackgroundPermissions backgroundPermissions(Ref ref) =>
    AppPlatform.current == AppPlatform.android ? const AndroidBackgroundPermissions() : const NoBackgroundPermissions();

/// Desktop folder picker for the downloads folder (spec-08 §8.3); null when canceled.
typedef DirectoryPicker = Future<String?> Function({String? initialDirectory});

@Riverpod(keepAlive: true)
DirectoryPicker directoryPicker(Ref ref) =>
    ({String? initialDirectory}) => getDirectoryPath(initialDirectory: initialDirectory);
