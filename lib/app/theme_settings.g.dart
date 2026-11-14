// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Light / system / dark (spec-09 key `theme_brightness`, stored by `ThemeMode.name`).

@ProviderFor(ThemeBrightness)
final themeBrightnessProvider = ThemeBrightnessProvider._();

/// Light / system / dark (spec-09 key `theme_brightness`, stored by `ThemeMode.name`).
final class ThemeBrightnessProvider extends $NotifierProvider<ThemeBrightness, ThemeMode> {
  /// Light / system / dark (spec-09 key `theme_brightness`, stored by `ThemeMode.name`).
  ThemeBrightnessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeBrightnessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeBrightnessHash();

  @$internal
  @override
  ThemeBrightness create() => ThemeBrightness();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<ThemeMode>(value));
  }
}

String _$themeBrightnessHash() => r'246bb639d6cfe0c2ba529bae6bd3f0484a1d77f6';

/// Light / system / dark (spec-09 key `theme_brightness`, stored by `ThemeMode.name`).

abstract class _$ThemeBrightness extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<ThemeMode, ThemeMode>, ThemeMode, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Spec-09 key `theme_color_scheme`, stored by `AppColorScheme.name`.

@ProviderFor(ThemeColorScheme)
final themeColorSchemeProvider = ThemeColorSchemeProvider._();

/// Spec-09 key `theme_color_scheme`, stored by `AppColorScheme.name`.
final class ThemeColorSchemeProvider extends $NotifierProvider<ThemeColorScheme, AppColorScheme> {
  /// Spec-09 key `theme_color_scheme`, stored by `AppColorScheme.name`.
  ThemeColorSchemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeColorSchemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeColorSchemeHash();

  @$internal
  @override
  ThemeColorScheme create() => ThemeColorScheme();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppColorScheme value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AppColorScheme>(value));
  }
}

String _$themeColorSchemeHash() => r'2541eaf313229ce04313251df4daa44f9190fcee';

/// Spec-09 key `theme_color_scheme`, stored by `AppColorScheme.name`.

abstract class _$ThemeColorScheme extends $Notifier<AppColorScheme> {
  AppColorScheme build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppColorScheme, AppColorScheme>;
    final element =
        ref.element
            as $ClassProviderElement<AnyNotifier<AppColorScheme, AppColorScheme>, AppColorScheme, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
