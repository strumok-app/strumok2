// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persisted player settings (spec-09 keys, enums stored by `.name`).

@ProviderFor(PlayerSettings)
final playerSettingsProvider = PlayerSettingsProvider._();

/// Persisted player settings (spec-09 keys, enums stored by `.name`).
final class PlayerSettingsProvider
    extends $NotifierProvider<PlayerSettings, PlayerPreferences> {
  /// Persisted player settings (spec-09 keys, enums stored by `.name`).
  PlayerSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerSettingsHash();

  @$internal
  @override
  PlayerSettings create() => PlayerSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerPreferences>(value),
    );
  }
}

String _$playerSettingsHash() => r'8a0c1b80f2ef1d3bacdb21a4cc05eca929fbc78e';

/// Persisted player settings (spec-09 keys, enums stored by `.name`).

abstract class _$PlayerSettings extends $Notifier<PlayerPreferences> {
  PlayerPreferences build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlayerPreferences, PlayerPreferences>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerPreferences, PlayerPreferences>,
              PlayerPreferences,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
