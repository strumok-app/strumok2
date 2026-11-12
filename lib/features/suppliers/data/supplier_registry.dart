import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config.dart';
import '../../../core/network/http_client.dart';
import '../../../core/platform/app_paths.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/storage/app_preferences.dart';
import '../domain/ffi_bundle_info.dart';
import 'supplier_bundle_installer.dart';

part 'supplier_registry.g.dart';

final _log = Logger('SupplierRegistry');

sealed class SupplierBundleState {
  const SupplierBundleState();
}

/// Not installed, file missing, incompatible or failed to load: the startup guard shows the install prompt.
final class SupplierBundleMissing extends SupplierBundleState {
  final Object? error;

  const SupplierBundleMissing([this.error]);
}

final class SupplierBundleReady extends SupplierBundleState {
  final ContentSupplierBundle bundle;

  /// Null for the developer override (`FFI_SUPPLIER_LIBS_DIR`).
  final FfiBundleInfo? info;

  const SupplierBundleReady(this.bundle, this.info);
}

/// Download key for this device's platform/ABI; computed in main().
@Riverpod(keepAlive: true)
String? bundleDownloadKey(Ref ref) =>
    throw UnimplementedError('bundleDownloadKeyProvider must be overridden in main()');

/// Bundle loaded before runApp(); overridden in main().
@Riverpod(keepAlive: true)
SupplierBundleState initialSupplierBundle(Ref ref) =>
    throw UnimplementedError('initialSupplierBundleProvider must be overridden in main()');

@Riverpod(keepAlive: true)
SupplierBundleInstaller supplierBundleInstaller(Ref ref) => SupplierBundleInstaller(
  client: ref.watch(httpClientProvider),
  directory: ref.watch(appPathsProvider).ffi,
  platform: AppPlatform.current,
  downloadKey: ref.watch(bundleDownloadKeyProvider),
);

@Riverpod(keepAlive: true)
class SupplierRegistry extends _$SupplierRegistry {
  @override
  SupplierBundleState build() => ref.watch(initialSupplierBundleProvider);

  /// Hot swap (spec-11 §11.1). Dependent providers rebuild because [suppliersProvider] changes.
  Future<void> activate(ContentSupplierBundle bundle, FfiBundleInfo info) async {
    await ref.read(appPreferencesProvider).setJson(AppPreferences.ffiSupplierBundleInfo, info.toJson());
    // SPEC: the previous library is not dlclose'd at runtime because calls may still be in flight;
    // it is released at the next app start (allowed by spec-11 §11.1).
    state = SupplierBundleReady(bundle, info);
    await ref.read(supplierBundleInstallerProvider).deleteOtherVersions(info);
  }
}

@Riverpod(keepAlive: true)
List<ContentSupplier> suppliers(Ref ref) => switch (ref.watch(supplierRegistryProvider)) {
  SupplierBundleReady(:final bundle) => bundle.suppliers,
  SupplierBundleMissing() => const [],
};

@riverpod
ContentSupplier supplierByName(Ref ref, String name) =>
    ref.watch(suppliersProvider).where((s) => s.name == name).firstOrNull ?? (throw SupplierNotFoundException(name));

class SupplierNotFoundException implements Exception {
  final String name;

  const SupplierNotFoundException(this.name);

  @override
  String toString() => 'Supplier "$name" is not available';
}

FfiBundleInfo? installedBundleInfo(AppPreferences prefs) {
  final json = prefs.getJson(AppPreferences.ffiSupplierBundleInfo);
  if (json == null) return null;
  try {
    return FfiBundleInfo.fromJson(json);
  } catch (e) {
    _log.warning('Invalid stored bundle info', e);
    return null;
  }
}

/// Startup load (spec-02 §2.4): dev override, otherwise the installed compatible bundle.
Future<SupplierBundleState> loadInitialSupplierBundle({
  required AppPreferences prefs,
  required SupplierBundleInstaller installer,
}) async {
  if (AppConfig.hasDevSupplierLib) {
    final dir = p.join(Directory.current.path, AppConfig.ffiSupplierLibsDir);
    try {
      return SupplierBundleReady(await installer.loader(dir, AppConfig.ffiSupplierLibName), null);
    } catch (e, st) {
      _log.severe('Failed to load dev supplier lib from $dir', e, st);
      return SupplierBundleMissing(e);
    }
  }

  final info = installedBundleInfo(prefs);
  if (info == null) return const SupplierBundleMissing();
  try {
    final bundle = await installer.loadInstalled(info);
    if (bundle == null) return const SupplierBundleMissing();
    await installer.deleteOtherVersions(info);
    return SupplierBundleReady(bundle, info);
  } catch (e, st) {
    _log.severe('Failed to load supplier bundle ${info.libName}', e, st);
    return SupplierBundleMissing(e);
  }
}
