// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App package version (pubspec `version`); overridden in main().

@ProviderFor(currentAppVersion)
final currentAppVersionProvider = CurrentAppVersionProvider._();

/// App package version (pubspec `version`); overridden in main().

final class CurrentAppVersionProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// App package version (pubspec `version`); overridden in main().
  CurrentAppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAppVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAppVersionHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return currentAppVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$currentAppVersionHash() => r'b33f5e8f204dc9df23919d23577d6ffe99aa365b';

@ProviderFor(LatestSupplierBundle)
final latestSupplierBundleProvider = LatestSupplierBundleProvider._();

final class LatestSupplierBundleProvider
    extends
        $NotifierProvider<
          LatestSupplierBundle,
          UpdateCheckState<FfiBundleInfo>
        > {
  LatestSupplierBundleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestSupplierBundleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestSupplierBundleHash();

  @$internal
  @override
  LatestSupplierBundle create() => LatestSupplierBundle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateCheckState<FfiBundleInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateCheckState<FfiBundleInfo>>(
        value,
      ),
    );
  }
}

String _$latestSupplierBundleHash() =>
    r'8ba0a57892767da9e0996c1dd0c732645296678c';

abstract class _$LatestSupplierBundle
    extends $Notifier<UpdateCheckState<FfiBundleInfo>> {
  UpdateCheckState<FfiBundleInfo> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              UpdateCheckState<FfiBundleInfo>,
              UpdateCheckState<FfiBundleInfo>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                UpdateCheckState<FfiBundleInfo>,
                UpdateCheckState<FfiBundleInfo>
              >,
              UpdateCheckState<FfiBundleInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(LatestAppRelease)
final latestAppReleaseProvider = LatestAppReleaseProvider._();

final class LatestAppReleaseProvider
    extends $NotifierProvider<LatestAppRelease, UpdateCheckState<AppRelease>> {
  LatestAppReleaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestAppReleaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestAppReleaseHash();

  @$internal
  @override
  LatestAppRelease create() => LatestAppRelease();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateCheckState<AppRelease> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateCheckState<AppRelease>>(value),
    );
  }
}

String _$latestAppReleaseHash() => r'5a810dc934a81401a15b5609030efdea8e4f267e';

abstract class _$LatestAppRelease
    extends $Notifier<UpdateCheckState<AppRelease>> {
  UpdateCheckState<AppRelease> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<UpdateCheckState<AppRelease>, UpdateCheckState<AppRelease>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                UpdateCheckState<AppRelease>,
                UpdateCheckState<AppRelease>
              >,
              UpdateCheckState<AppRelease>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(supplierBundleUpdateStatus)
final supplierBundleUpdateStatusProvider =
    SupplierBundleUpdateStatusProvider._();

final class SupplierBundleUpdateStatusProvider
    extends
        $FunctionalProvider<
          BundleUpdateStatus,
          BundleUpdateStatus,
          BundleUpdateStatus
        >
    with $Provider<BundleUpdateStatus> {
  SupplierBundleUpdateStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierBundleUpdateStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierBundleUpdateStatusHash();

  @$internal
  @override
  $ProviderElement<BundleUpdateStatus> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BundleUpdateStatus create(Ref ref) {
    return supplierBundleUpdateStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BundleUpdateStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BundleUpdateStatus>(value),
    );
  }
}

String _$supplierBundleUpdateStatusHash() =>
    r'07ca41145283d26775400d95125bd5d4ab800956';

/// Newer release, or null.

@ProviderFor(availableAppUpdate)
final availableAppUpdateProvider = AvailableAppUpdateProvider._();

/// Newer release, or null.

final class AvailableAppUpdateProvider
    extends $FunctionalProvider<AppRelease?, AppRelease?, AppRelease?>
    with $Provider<AppRelease?> {
  /// Newer release, or null.
  AvailableAppUpdateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableAppUpdateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableAppUpdateHash();

  @$internal
  @override
  $ProviderElement<AppRelease?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppRelease? create(Ref ref) {
    return availableAppUpdate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppRelease? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppRelease?>(value),
    );
  }
}

String _$availableAppUpdateHash() =>
    r'58ffd89f3dee77c59fce40e5b928afd7efef59dd';

/// Drives the badge on the account/settings entry (spec-01).

@ProviderFor(hasUpdateNotice)
final hasUpdateNoticeProvider = HasUpdateNoticeProvider._();

/// Drives the badge on the account/settings entry (spec-01).

final class HasUpdateNoticeProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Drives the badge on the account/settings entry (spec-01).
  HasUpdateNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasUpdateNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasUpdateNoticeHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasUpdateNotice(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasUpdateNoticeHash() => r'86d7896f2415d8a95dd712fd1c13cb0ea0f3f162';

@ProviderFor(SupplierBundleInstallController)
final supplierBundleInstallControllerProvider =
    SupplierBundleInstallControllerProvider._();

final class SupplierBundleInstallControllerProvider
    extends $NotifierProvider<SupplierBundleInstallController, InstallState> {
  SupplierBundleInstallControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierBundleInstallControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierBundleInstallControllerHash();

  @$internal
  @override
  SupplierBundleInstallController create() => SupplierBundleInstallController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallState>(value),
    );
  }
}

String _$supplierBundleInstallControllerHash() =>
    r'4eba2e2323a08dace8166ce29c6d23f9f66d3504';

abstract class _$SupplierBundleInstallController
    extends $Notifier<InstallState> {
  InstallState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InstallState, InstallState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InstallState, InstallState>,
              InstallState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AppUpdateInstallController)
final appUpdateInstallControllerProvider =
    AppUpdateInstallControllerProvider._();

final class AppUpdateInstallControllerProvider
    extends $NotifierProvider<AppUpdateInstallController, InstallState> {
  AppUpdateInstallControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateInstallControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateInstallControllerHash();

  @$internal
  @override
  AppUpdateInstallController create() => AppUpdateInstallController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallState>(value),
    );
  }
}

String _$appUpdateInstallControllerHash() =>
    r'9ee39acaec57a33260d0e08b20c7c12fe70c9152';

abstract class _$AppUpdateInstallController extends $Notifier<InstallState> {
  InstallState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InstallState, InstallState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InstallState, InstallState>,
              InstallState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
