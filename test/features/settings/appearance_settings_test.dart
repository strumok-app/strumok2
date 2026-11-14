import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/theme.dart';
import 'package:strumok/app/theme_settings.dart';
import 'package:strumok/core/localization.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  testAppWidgets('restores saved language and theme', (tester) async {
    final prefs = await createTestPreferences({
      AppPreferences.userLanguage: 'en',
      AppPreferences.themeBrightness: 'dark',
      AppPreferences.themeColorScheme: 'neonCyan',
    });
    final container = await pumpApp(tester, prefs: prefs);

    expect(container.read(appLocaleProvider), const Locale('en'));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme!.colorScheme, buildColorScheme(AppColorScheme.neonCyan, Brightness.dark));
  });

  testAppWidgets('unknown saved values fall back to defaults', (tester) async {
    final prefs = await createTestPreferences({
      AppPreferences.userLanguage: 'de',
      AppPreferences.themeBrightness: 'bogus',
      AppPreferences.themeColorScheme: 'bogus',
    });
    final container = await pumpApp(tester, prefs: prefs);

    expect(container.read(appLocaleProvider), const Locale('uk'));
    expect(container.read(themeBrightnessProvider), ThemeMode.system);
    expect(container.read(themeColorSchemeProvider), AppColorScheme.olive);
  });

  testAppWidgets('settings page changes and persists language, brightness and color scheme', (tester) async {
    final container = await pumpApp(tester, size: const Size(1280, 1600));
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Темна'));
    await tester.tap(find.text('Кобальт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme!.colorScheme, buildColorScheme(AppColorScheme.cobalt, Brightness.light));
    expect(find.text('Color scheme'), findsOneWidget);

    final prefs = container.read(appPreferencesProvider);
    expect(prefs.getString(AppPreferences.themeBrightness), 'dark');
    expect(prefs.getString(AppPreferences.themeColorScheme), 'cobalt');
    expect(prefs.getString(AppPreferences.userLanguage), 'en');
  });

  testAppWidgets('tv: color scheme is selectable with D-pad', (tester) async {
    final container = await pumpApp(tester, size: const Size(1280, 1600), deviceClass: DeviceClass.tv);
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();

    Focus.of(tester.element(find.text('Олива'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(container.read(themeColorSchemeProvider), AppColorScheme.crimson);
  });

  test('every color scheme builds light and dark themes', () {
    for (final scheme in AppColorScheme.values) {
      for (final brightness in Brightness.values) {
        expect(buildTheme(scheme, brightness).colorScheme.brightness, brightness);
      }
    }
  });
}
