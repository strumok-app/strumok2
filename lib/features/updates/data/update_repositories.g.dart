// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_repositories.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supplierBundleInfoRepository)
final supplierBundleInfoRepositoryProvider = SupplierBundleInfoRepositoryProvider._();

final class SupplierBundleInfoRepositoryProvider
    extends
        $FunctionalProvider<SupplierBundleInfoRepository, SupplierBundleInfoRepository, SupplierBundleInfoRepository>
    with $Provider<SupplierBundleInfoRepository> {
  SupplierBundleInfoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierBundleInfoRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierBundleInfoRepositoryHash();

  @$internal
  @override
  $ProviderElement<SupplierBundleInfoRepository> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  SupplierBundleInfoRepository create(Ref ref) {
    return supplierBundleInfoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupplierBundleInfoRepository value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<SupplierBundleInfoRepository>(value));
  }
}

String _$supplierBundleInfoRepositoryHash() => r'6525bee5d599ee2d721b508fd66ccd01d04e1c13';

@ProviderFor(appReleaseRepository)
final appReleaseRepositoryProvider = AppReleaseRepositoryProvider._();

final class AppReleaseRepositoryProvider
    extends $FunctionalProvider<AppReleaseRepository, AppReleaseRepository, AppReleaseRepository>
    with $Provider<AppReleaseRepository> {
  AppReleaseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appReleaseRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appReleaseRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppReleaseRepository> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  AppReleaseRepository create(Ref ref) {
    return appReleaseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppReleaseRepository value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AppReleaseRepository>(value));
  }
}

String _$appReleaseRepositoryHash() => r'e10ef0c55e6c3800844b298c33b8edd95b14459f';
