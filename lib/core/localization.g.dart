// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'localization.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// UI language: `uk` by default; becomes user-selectable with the language setting (spec-09).

@ProviderFor(appLocale)
final appLocaleProvider = AppLocaleProvider._();

/// UI language: `uk` by default; becomes user-selectable with the language setting (spec-09).

final class AppLocaleProvider extends $FunctionalProvider<Locale, Locale, Locale> with $Provider<Locale> {
  /// UI language: `uk` by default; becomes user-selectable with the language setting (spec-09).
  AppLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocaleHash();

  @$internal
  @override
  $ProviderElement<Locale> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  Locale create(Ref ref) {
    return appLocale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<Locale>(value));
  }
}

String _$appLocaleHash() => r'64f4d0e39ca616b5fff69370579d5ae2a93cac53';
