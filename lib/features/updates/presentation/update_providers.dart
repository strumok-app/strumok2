import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/file_downloader.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/utils/semver.dart';
import '../../suppliers/data/supplier_registry.dart';
import '../../suppliers/domain/ffi_bundle_info.dart';
import '../data/app_installer.dart';
import '../data/update_repositories.dart';
import '../domain/app_release.dart';
import '../domain/bundle_update_status.dart';
import '../domain/update_check.dart';

part 'update_providers.g.dart';

final _log = Logger('Updates');

/// App package version (pubspec `version`); overridden in main().
@Riverpod(keepAlive: true)
String currentAppVersion(Ref ref) => throw UnimplementedError('currentAppVersionProvider must be overridden in main()');

@Riverpod(keepAlive: true)
class LatestSupplierBundle extends _$LatestSupplierBundle {
  @override
  UpdateCheckState<FfiBundleInfo> build() {
    final cached = ref.read(appPreferencesProvider).getJson(AppPreferences.ffiUpdateLatestInfo);
    try {
      return UpdateCheckState(latest: cached == null ? null : FfiBundleInfo.fromJson(cached));
    } catch (_) {
      return const UpdateCheckState();
    }
  }

  /// [silent] = startup check: throttled, errors only logged.
  Future<void> check({bool silent = false}) async {
    final prefs = ref.read(appPreferencesProvider);
    final now = ref.read(clockProvider)();
    if (silent && !isUpdateCheckDue(prefs.getDateTime(AppPreferences.ffiUpdateLastCheck), now)) return;
    if (state.checking) return;

    state = UpdateCheckState(latest: state.latest, checking: !silent);
    try {
      final latest = await ref.read(supplierBundleInfoRepositoryProvider).fetchLatest();
      await prefs.setJson(AppPreferences.ffiUpdateLatestInfo, latest.toJson());
      await prefs.setDateTime(AppPreferences.ffiUpdateLastCheck, now);
      if (ref.mounted) state = UpdateCheckState(latest: latest);
    } catch (e, st) {
      _log.warning('Supplier bundle update check failed', e, e is UpdateCheckNotConfiguredException ? null : st);
      if (ref.mounted) state = UpdateCheckState(latest: state.latest, error: silent ? null : e);
    }
  }
}

@Riverpod(keepAlive: true)
class LatestAppRelease extends _$LatestAppRelease {
  @override
  UpdateCheckState<AppRelease> build() {
    final cached = ref.read(appPreferencesProvider).getJson(AppPreferences.appUpdateLatestRelease);
    return UpdateCheckState(latest: cached == null ? null : AppRelease.tryParse(cached));
  }

  /// [silent] = startup check: throttled, errors only logged.
  Future<void> check({bool silent = false}) async {
    final prefs = ref.read(appPreferencesProvider);
    final now = ref.read(clockProvider)();
    if (silent && !isUpdateCheckDue(prefs.getDateTime(AppPreferences.appUpdateLastCheck), now)) return;
    if (state.checking) return;

    state = UpdateCheckState(latest: state.latest, checking: !silent);
    try {
      final latest = await ref.read(appReleaseRepositoryProvider).fetchLatest();
      await prefs.setJson(AppPreferences.appUpdateLatestRelease, latest.toJson());
      await prefs.setDateTime(AppPreferences.appUpdateLastCheck, now);
      if (ref.mounted) state = UpdateCheckState(latest: latest);
    } catch (e, st) {
      _log.warning('App update check failed', e, e is UpdateCheckNotConfiguredException ? null : st);
      if (ref.mounted) state = UpdateCheckState(latest: state.latest, error: silent ? null : e);
    }
  }
}

@Riverpod(keepAlive: true)
BundleUpdateStatus supplierBundleUpdateStatus(Ref ref) {
  final latest = ref.watch(latestSupplierBundleProvider.select((s) => s.latest));
  return switch (ref.watch(supplierRegistryProvider)) {
    SupplierBundleReady(info: null) => BundleUpdateStatus.unknown,
    SupplierBundleReady(:final info) => bundleUpdateStatus(installed: info, latest: latest),
    SupplierBundleMissing() => bundleUpdateStatus(installed: null, latest: latest),
  };
}

/// Newer release, or null.
@Riverpod(keepAlive: true)
AppRelease? availableAppUpdate(Ref ref) {
  final latest = ref.watch(latestAppReleaseProvider.select((s) => s.latest));
  final current = SemVer.tryParse(ref.watch(currentAppVersionProvider));
  if (latest == null || current == null) return null;
  return latest.version > current ? latest : null;
}

/// Drives the badge on the account/settings entry (spec-01).
@Riverpod(keepAlive: true)
bool hasUpdateNotice(Ref ref) =>
    ref.watch(availableAppUpdateProvider) != null ||
    switch (ref.watch(supplierBundleUpdateStatusProvider)) {
      BundleUpdateStatus.updateAvailable || BundleUpdateStatus.appUpdateRequired => true,
      BundleUpdateStatus.unknown || BundleUpdateStatus.upToDate => false,
    };

/// Maps byte progress to [InstallInProgress], emitting only on whole-percent changes.
DownloadProgressCallback _progressTo(void Function(InstallState) emit) {
  var lastPercent = -1;
  return (received, total) {
    if (total == null || total <= 0) return;
    final percent = received * 100 ~/ total;
    if (percent == lastPercent) return;
    lastPercent = percent;
    emit(InstallInProgress(percent / 100));
  };
}

@Riverpod(keepAlive: true)
class SupplierBundleInstallController extends _$SupplierBundleInstallController {
  DownloadCancelToken? _cancelToken;

  @override
  InstallState build() => const InstallIdle();

  /// Download → load → swap (spec-11 §11.1). On failure the active bundle stays untouched.
  Future<bool> install(FfiBundleInfo info) async {
    if (state is InstallInProgress) return false;
    final token = _cancelToken = DownloadCancelToken();
    state = const InstallInProgress();
    try {
      final bundle = await ref
          .read(supplierBundleInstallerProvider)
          .install(
            info,
            cancelToken: token,
            onProgress: _progressTo((s) {
              if (ref.mounted) state = s;
            }),
          );
      await ref.read(supplierRegistryProvider.notifier).activate(bundle, info);
      if (ref.mounted) state = const InstallIdle();
      return true;
    } on DownloadCanceledException {
      if (ref.mounted) state = const InstallIdle();
      return false;
    } catch (e, st) {
      _log.severe('Supplier bundle install failed', e, st);
      if (ref.mounted) state = InstallFailed(e);
      return false;
    }
  }

  void cancel() => _cancelToken?.cancel();
}

@Riverpod(keepAlive: true)
class AppUpdateInstallController extends _$AppUpdateInstallController {
  DownloadCancelToken? _cancelToken;

  @override
  InstallState build() => const InstallIdle();

  /// Only ever triggered by an explicit user action (spec-11 §11.2).
  Future<void> install(AppRelease release) async {
    if (state is InstallInProgress) return;
    final asset = release.assetFor(AppPlatform.current);
    if (asset == null) {
      state = const InstallFailed(NoReleaseAssetException());
      return;
    }
    final token = _cancelToken = DownloadCancelToken();
    state = const InstallInProgress();
    try {
      await ref
          .read(appInstallerProvider)
          .install(
            release,
            asset,
            cancelToken: token,
            onProgress: _progressTo((s) {
              if (ref.mounted) state = s;
            }),
          );
      if (ref.mounted) state = const InstallIdle();
    } on DownloadCanceledException {
      if (ref.mounted) state = const InstallIdle();
    } catch (e, st) {
      _log.severe('App update failed', e, st);
      if (ref.mounted) state = InstallFailed(e);
    }
  }

  void cancel() => _cancelToken?.cancel();
}
