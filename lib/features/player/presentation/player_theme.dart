import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/theme.dart';
import '../../../app/theme_settings.dart';

part 'player_theme.g.dart';

/// Controls sit on video: the dark variant of the user's color scheme whatever the app brightness, so accents
/// (sliders, progress, focus) stay visible on black (e.g. the monochrome scheme is black on light). Side sheets
/// are routes and keep the app theme.
@riverpod
ThemeData playerTheme(Ref ref) {
  final theme = buildTheme(ref.watch(themeColorSchemeProvider), Brightness.dark);
  return theme.copyWith(
    iconTheme: theme.iconTheme.copyWith(color: Colors.white),
    textTheme: theme.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    iconButtonTheme: IconButtonThemeData(
      style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? Colors.white38 : Colors.white,
        ),
      ),
    ),
  );
}
