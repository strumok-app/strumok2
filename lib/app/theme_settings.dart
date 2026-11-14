import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/storage/app_preferences.dart';
import 'theme.dart';

part 'theme_settings.g.dart';

/// Light / system / dark (spec-09 key `theme_brightness`, stored by `ThemeMode.name`).
@Riverpod(keepAlive: true)
class ThemeBrightness extends _$ThemeBrightness {
  @override
  ThemeMode build() {
    final saved = ref.read(appPreferencesProvider).getString(AppPreferences.themeBrightness);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode value) async {
    state = value;
    await ref.read(appPreferencesProvider).setString(AppPreferences.themeBrightness, value.name);
  }
}

/// Spec-09 key `theme_color_scheme`, stored by `AppColorScheme.name`.
@Riverpod(keepAlive: true)
class ThemeColorScheme extends _$ThemeColorScheme {
  @override
  AppColorScheme build() {
    final saved = ref.read(appPreferencesProvider).getString(AppPreferences.themeColorScheme);
    return AppColorScheme.values.asNameMap()[saved] ?? AppColorScheme.defaultScheme;
  }

  Future<void> set(AppColorScheme value) async {
    state = value;
    await ref.read(appPreferencesProvider).setString(AppPreferences.themeColorScheme, value.name);
  }
}
