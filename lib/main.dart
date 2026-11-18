import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/platform/app_platform.dart';
import 'core/platform/single_instance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();

  // Desktop: one instance at a time; a second start brings the running window to the front and quits before any
  // window is shown (the runners show it after the first frame).
  SingleInstance? instance;
  if (AppPlatform.current != AppPlatform.android) {
    instance = await SingleInstance.acquire(await getApplicationSupportDirectory());
    if (instance == null) exit(0);
  }

  final overrides = await bootstrap();
  instance?.activations.listen((_) => unawaited(bringWindowToFront()));

  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [...overrides, singleInstanceProvider.overrideWithValue(instance)],
      child: const StrumokApp(),
    ),
  );
}

void _setupLogging() {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((record) {
    final error = record.error == null ? '' : ' ${record.error}';
    // ignore: avoid_print
    print('${record.time.toIso8601String()} ${record.level.name} ${record.loggerName}: ${record.message}$error');
    if (record.stackTrace != null) debugPrintStack(stackTrace: record.stackTrace);
  });
}
