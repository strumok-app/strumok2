// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_registry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Download key for this device's platform/ABI; computed in main().

@ProviderFor(bundleDownloadKey)
final bundleDownloadKeyProvider = BundleDownloadKeyProvider._();

/// Download key for this device's platform/ABI; computed in main().

final class BundleDownloadKeyProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Download key for this device's platform/ABI; computed in main().
  BundleDownloadKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bundleDownloadKeyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bundleDownloadKeyHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return bundleDownloadKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$bundleDownloadKeyHash() => r'56f5b63eb0a5cd8458db99aee534d3e3694c3e52';

/// Bundle loaded before runApp(); overridden in main().

@ProviderFor(initialSupplierBundle)
final initialSupplierBundleProvider = InitialSupplierBundleProvider._();

/// Bundle loaded before runApp(); overridden in main().

final class InitialSupplierBundleProvider
    extends
        $FunctionalProvider<
          SupplierBundleState,
          SupplierBundleState,
          SupplierBundleState
        >
    with $Provider<SupplierBundleState> {
  /// Bundle loaded before runApp(); overridden in main().
  InitialSupplierBundleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialSupplierBundleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialSupplierBundleHash();

  @$internal
  @override
  $ProviderElement<SupplierBundleState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupplierBundleState create(Ref ref) {
    return initialSupplierBundle(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupplierBundleState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupplierBundleState>(value),
    );
  }
}

String _$initialSupplierBundleHash() =>
    r'521e9f1d5dfb92b5ccbe90f54bdc23a1fa177b88';

@ProviderFor(supplierBundleInstaller)
final supplierBundleInstallerProvider = SupplierBundleInstallerProvider._();

final class SupplierBundleInstallerProvider
    extends
        $FunctionalProvider<
          SupplierBundleInstaller,
          SupplierBundleInstaller,
          SupplierBundleInstaller
        >
    with $Provider<SupplierBundleInstaller> {
  SupplierBundleInstallerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierBundleInstallerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierBundleInstallerHash();

  @$internal
  @override
  $ProviderElement<SupplierBundleInstaller> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupplierBundleInstaller create(Ref ref) {
    return supplierBundleInstaller(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupplierBundleInstaller value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupplierBundleInstaller>(value),
    );
  }
}

String _$supplierBundleInstallerHash() =>
    r'097c848fd486db782a9cd570c1a8512d05ff7128';

@ProviderFor(SupplierRegistry)
final supplierRegistryProvider = SupplierRegistryProvider._();

final class SupplierRegistryProvider
    extends $NotifierProvider<SupplierRegistry, SupplierBundleState> {
  SupplierRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierRegistryHash();

  @$internal
  @override
  SupplierRegistry create() => SupplierRegistry();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupplierBundleState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupplierBundleState>(value),
    );
  }
}

String _$supplierRegistryHash() => r'1b2b2b733f655fc9b241d555efbe8fca61e4ffad';

abstract class _$SupplierRegistry extends $Notifier<SupplierBundleState> {
  SupplierBundleState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SupplierBundleState, SupplierBundleState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SupplierBundleState, SupplierBundleState>,
              SupplierBundleState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(suppliers)
final suppliersProvider = SuppliersProvider._();

final class SuppliersProvider
    extends
        $FunctionalProvider<
          List<ContentSupplier>,
          List<ContentSupplier>,
          List<ContentSupplier>
        >
    with $Provider<List<ContentSupplier>> {
  SuppliersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suppliersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suppliersHash();

  @$internal
  @override
  $ProviderElement<List<ContentSupplier>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ContentSupplier> create(Ref ref) {
    return suppliers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ContentSupplier> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ContentSupplier>>(value),
    );
  }
}

String _$suppliersHash() => r'cd6a54eab96558705497020b1b2dc78fffef143f';

@ProviderFor(supplierByName)
final supplierByNameProvider = SupplierByNameFamily._();

final class SupplierByNameProvider
    extends
        $FunctionalProvider<ContentSupplier, ContentSupplier, ContentSupplier>
    with $Provider<ContentSupplier> {
  SupplierByNameProvider._({
    required SupplierByNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'supplierByNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$supplierByNameHash();

  @override
  String toString() {
    return r'supplierByNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ContentSupplier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContentSupplier create(Ref ref) {
    final argument = this.argument as String;
    return supplierByName(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentSupplier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentSupplier>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SupplierByNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$supplierByNameHash() => r'933671f01b2d5208080a432d914547b17d1f5485';

final class SupplierByNameFamily extends $Family
    with $FunctionalFamilyOverride<ContentSupplier, String> {
  SupplierByNameFamily._()
    : super(
        retry: null,
        name: r'supplierByNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SupplierByNameProvider call(String name) =>
      SupplierByNameProvider._(argument: name, from: this);

  @override
  String toString() => r'supplierByNameProvider';
}
