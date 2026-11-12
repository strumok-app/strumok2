// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_preferences.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appPreferences)
final appPreferencesProvider = AppPreferencesProvider._();

final class AppPreferencesProvider extends $FunctionalProvider<AppPreferences, AppPreferences, AppPreferences>
    with $Provider<AppPreferences> {
  AppPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPreferencesHash();

  @$internal
  @override
  $ProviderElement<AppPreferences> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  AppPreferences create(Ref ref) {
    return appPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppPreferences value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AppPreferences>(value));
  }
}

String _$appPreferencesHash() => r'70710a21d0692cc2251c7c80b8ca283a3996d3a2';

/// Overridable clock for update-check throttling.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// Overridable clock for update-check throttling.

final class ClockProvider extends $FunctionalProvider<DateTime Function(), DateTime Function(), DateTime Function()>
    with $Provider<DateTime Function()> {
  /// Overridable clock for update-check throttling.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<DateTime Function()>(value));
  }
}

String _$clockHash() => r'3f65ad34ac6fcd532de9004042bdf2ed2bd85b13';
