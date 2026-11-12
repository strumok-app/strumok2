import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();

  final overrides = await bootstrap();

  runApp(ProviderScope(retry: (_, _) => null, overrides: overrides, child: const StrumokApp()));
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
