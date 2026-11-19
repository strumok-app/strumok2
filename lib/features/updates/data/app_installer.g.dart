// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_installer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appInstaller)
final appInstallerProvider = AppInstallerProvider._();

final class AppInstallerProvider
    extends $FunctionalProvider<AppInstaller, AppInstaller, AppInstaller>
    with $Provider<AppInstaller> {
  AppInstallerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appInstallerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInstallerHash();

  @$internal
  @override
  $ProviderElement<AppInstaller> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppInstaller create(Ref ref) {
    return appInstaller(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppInstaller value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppInstaller>(value),
    );
  }
}

String _$appInstallerHash() => r'9bc2547d0c0183cf5ec75b6a9528215c64b745af';
