// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_configs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ordered per-supplier configuration (spec-02 §2.5).

@ProviderFor(SupplierConfigs)
final supplierConfigsProvider = SupplierConfigsProvider._();

/// Ordered per-supplier configuration (spec-02 §2.5).
final class SupplierConfigsProvider
    extends $NotifierProvider<SupplierConfigs, List<SupplierConfig>> {
  /// Ordered per-supplier configuration (spec-02 §2.5).
  SupplierConfigsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierConfigsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierConfigsHash();

  @$internal
  @override
  SupplierConfigs create() => SupplierConfigs();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SupplierConfig> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SupplierConfig>>(value),
    );
  }
}

String _$supplierConfigsHash() => r'af49dd97500b6b15523e5e030410c1e25db4d42d';

/// Ordered per-supplier configuration (spec-02 §2.5).

abstract class _$SupplierConfigs extends $Notifier<List<SupplierConfig>> {
  List<SupplierConfig> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<SupplierConfig>, List<SupplierConfig>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<SupplierConfig>, List<SupplierConfig>>,
              List<SupplierConfig>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
