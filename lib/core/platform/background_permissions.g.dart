// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_permissions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backgroundPermissions)
final backgroundPermissionsProvider = BackgroundPermissionsProvider._();

final class BackgroundPermissionsProvider
    extends $FunctionalProvider<BackgroundPermissions, BackgroundPermissions, BackgroundPermissions>
    with $Provider<BackgroundPermissions> {
  BackgroundPermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundPermissionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundPermissionsHash();

  @$internal
  @override
  $ProviderElement<BackgroundPermissions> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  BackgroundPermissions create(Ref ref) {
    return backgroundPermissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundPermissions value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<BackgroundPermissions>(value));
  }
}

String _$backgroundPermissionsHash() => r'2b04d76dcecc2d5466f79bba673f3c48be4a5b89';

@ProviderFor(directoryPicker)
final directoryPickerProvider = DirectoryPickerProvider._();

final class DirectoryPickerProvider extends $FunctionalProvider<DirectoryPicker, DirectoryPicker, DirectoryPicker>
    with $Provider<DirectoryPicker> {
  DirectoryPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryPickerHash();

  @$internal
  @override
  $ProviderElement<DirectoryPicker> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  DirectoryPicker create(Ref ref) {
    return directoryPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryPicker value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<DirectoryPicker>(value));
  }
}

String _$directoryPickerHash() => r'927c05ad68ad94d8ba51990036feb8e067bbe8bc';
