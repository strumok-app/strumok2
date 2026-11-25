import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../core/network/http_client.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/app_platform.dart';
import '../core/platform/device_class.dart';
import '../core/storage/app_preferences.dart';
import '../features/player/data/pip/pip.dart';
import '../features/suppliers/data/supplier_bundle_installer.dart';
import '../features/suppliers/data/supplier_registry.dart';
import '../features/suppliers/domain/ffi_bundle_info.dart';
import '../features/updates/presentation/update_providers.dart';

final _log = Logger('bootstrap');

/// Initializes infrastructure needed before runApp() and returns the root `ProviderScope` overrides.
Future<List<Override>> bootstrap() async {
  final platform = AppPlatform.current;
  MediaKit.ensureInitialized();
  // Messages from the download service isolate (spec-08 §8.1).
  if (platform == AppPlatform.android) FlutterForegroundTask.initCommunicationPort();
  if (platform != AppPlatform.android) {
    await windowManager.ensureInitialized();
  }
  final (prefs, paths, deviceClass, packageInfo) = await (
    AppPreferences.create(),
    AppPaths.resolve(),
    detectDeviceClass(),
    PackageInfo.fromPlatform(),
  ).wait;
  final (client, pip) = await (
    createHttpClient(appVersion: packageInfo.version),
    createPip(platform, deviceClass),
  ).wait;

  final abis = platform == AppPlatform.android ? (await DeviceInfoPlugin().androidInfo).supportedAbis : <String>[];
  final downloadKey = selectBundleDownloadKey(platform, androidAbis: abis);

  final installer = SupplierBundleInstaller(
    client: client,
    directory: paths.ffi,
    platform: platform,
    downloadKey: downloadKey,
  );
  final initialBundle = await loadInitialSupplierBundle(prefs: prefs, installer: installer);

  _log.info(
    'Device: ${deviceClass.name}, app ${packageInfo.version}, bundle key: $downloadKey, '
    'suppliers: ${initialBundle.runtimeType}',
  );

  return [
    appPreferencesProvider.overrideWithValue(prefs),
    appPathsProvider.overrideWithValue(paths),
    deviceClassProvider.overrideWithValue(deviceClass),
    currentAppVersionProvider.overrideWithValue(packageInfo.version),
    httpClientProvider.overrideWithValue(client),
    pipProvider.overrideWithValue(pip),
    bundleDownloadKeyProvider.overrideWithValue(downloadKey),
    initialSupplierBundleProvider.overrideWithValue(initialBundle),
  ];
}
