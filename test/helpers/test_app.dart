import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:strumok/app/app.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/platform/device_levels.dart';
import 'package:strumok/core/platform/window_fullscreen.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/player/data/video_backend.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import 'test_overrides.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1280, 720),
  DeviceClass deviceClass = DeviceClass.desktop,
  SupplierBundleState? bundle,
  AppPreferences? prefs,
  VideoBackend Function()? videoBackend,
  WindowFullscreen? windowFullscreen,
  BrightnessControl? brightness,
  VolumeControl? volume,
  http.Client? client,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final overrides = await testOverrides(
    deviceClass: deviceClass,
    bundle: bundle,
    prefs: prefs,
    videoBackend: videoBackend,
    windowFullscreen: windowFullscreen,
    brightness: brightness,
    volume: volume,
    client: client,
  );
  final container = ProviderContainer(overrides: [...overrides, ...extraOverrides]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const StrumokApp()));
  await tester.pumpAndSettle();
  return container;
}

/// [testWidgets] for app-level tests: unmounts the app and lets `cacheFor` timers expire before
/// the pending-timer check.
void testAppWidgets(String description, WidgetTesterCallback body) => testWidgets(description, (tester) async {
  await body(tester);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(hours: 1));
});
