// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_paths.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appPaths)
final appPathsProvider = AppPathsProvider._();

final class AppPathsProvider
    extends $FunctionalProvider<AppPaths, AppPaths, AppPaths>
    with $Provider<AppPaths> {
  AppPathsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPathsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPathsHash();

  @$internal
  @override
  $ProviderElement<AppPaths> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppPaths create(Ref ref) {
    return appPaths(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppPaths value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppPaths>(value),
    );
  }
}

String _$appPathsHash() => r'9c0de1b73e6bda62799beef9251553545c06ed4e';
