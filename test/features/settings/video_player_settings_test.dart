import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/player/domain/player_preferences.dart';
import 'package:strumok/features/player/domain/player_session.dart';
import 'package:strumok/features/player/presentation/player_settings.dart';
import 'package:strumok/features/player/presentation/subtitle_size.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<ProviderContainer> openSettings(WidgetTester tester, {DeviceClass deviceClass = DeviceClass.desktop}) async {
    final container = await pumpApp(tester, size: const Size(1280, 2400), deviceClass: deviceClass);
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();
    return container;
  }

  testAppWidgets('video player section changes and persists start from, on end, shuffle and subtitle size', (
    tester,
  ) async {
    final container = await openSettings(tester);
    expect(find.text('Відеоплеєр'), findsOneWidget);
    expect(find.byKey(const ValueKey('fixedPosition')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('startFrom-fromFixedPosition')));
    await tester.pumpAndSettle();
    final fixed = find.byKey(const ValueKey('fixedPosition'));
    await tester.tap(find.descendant(of: fixed, matching: find.byTooltip('Збільшити')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: fixed, matching: find.text('0:10')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('endAction-doNothing')));
    await tester.tap(find.byKey(const ValueKey('shuffle')));
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('subtitleSize')), matching: find.byTooltip('Зменшити')),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(playerSettingsProvider),
      const PlayerPreferences(
        startFrom: StartFrom.fromFixedPosition,
        fixedPosition: 10,
        endAction: EndAction.doNothing,
        shuffle: true,
      ),
    );
    expect(container.read(subtitleSizeProvider), SubtitleSize.defaultSize - SubtitleSize.step);
    final prefs = container.read(appPreferencesProvider);
    expect(prefs.getString(AppPreferences.videoPlayerEndsAction), 'doNothing');
    expect(prefs.getBool(AppPreferences.videoPlayerShuffleMode), isTrue);
  });

  testAppWidgets('tv: radio rows and the shuffle switch work with the D-pad', (tester) async {
    final container = await openSettings(tester, deviceClass: DeviceClass.tv);
    Focus.of(tester.element(find.text('Місця зупинки'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(container.read(playerSettingsProvider).startFrom, StartFrom.fromBeginning);
  });
}
