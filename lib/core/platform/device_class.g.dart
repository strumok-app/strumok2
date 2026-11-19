// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_class.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Computed once at startup; overridden on the root `ProviderScope`.

@ProviderFor(deviceClass)
final deviceClassProvider = DeviceClassProvider._();

/// Computed once at startup; overridden on the root `ProviderScope`.

final class DeviceClassProvider
    extends $FunctionalProvider<DeviceClass, DeviceClass, DeviceClass>
    with $Provider<DeviceClass> {
  /// Computed once at startup; overridden on the root `ProviderScope`.
  DeviceClassProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceClassProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceClassHash();

  @$internal
  @override
  $ProviderElement<DeviceClass> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceClass create(Ref ref) {
    return deviceClass(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceClass value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceClass>(value),
    );
  }
}

String _$deviceClassHash() => r'48d43aea179710e5871ef550ff07b62abef9cb0c';
