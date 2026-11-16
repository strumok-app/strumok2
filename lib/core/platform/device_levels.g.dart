// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_levels.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(brightnessControl)
final brightnessControlProvider = BrightnessControlProvider._();

final class BrightnessControlProvider
    extends $FunctionalProvider<BrightnessControl, BrightnessControl, BrightnessControl>
    with $Provider<BrightnessControl> {
  BrightnessControlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brightnessControlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brightnessControlHash();

  @$internal
  @override
  $ProviderElement<BrightnessControl> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  BrightnessControl create(Ref ref) {
    return brightnessControl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrightnessControl value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<BrightnessControl>(value));
  }
}

String _$brightnessControlHash() => r'e6f1d2e85c1f6732f020d2870069e2db1688c5b9';

@ProviderFor(volumeControl)
final volumeControlProvider = VolumeControlProvider._();

final class VolumeControlProvider extends $FunctionalProvider<VolumeControl, VolumeControl, VolumeControl>
    with $Provider<VolumeControl> {
  VolumeControlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'volumeControlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$volumeControlHash();

  @$internal
  @override
  $ProviderElement<VolumeControl> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  VolumeControl create(Ref ref) {
    return volumeControl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VolumeControl value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<VolumeControl>(value));
  }
}

String _$volumeControlHash() => r'4eb90914955f36c560528f063dd2e272ec486309';
