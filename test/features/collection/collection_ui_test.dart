import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/content_card.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/profiles/domain/profile.dart';
import 'package:strumok/features/profiles/presentation/profiles_providers.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  testAppWidgets('details → collection sheet → status shows on details, collection page and home', (tester) async {
    final supplier = FakeSupplier(
      'alpha',
      defaultChannels: const {},
      details: {'m1': FakeDetails('alpha', 'm1', title: 'Shadows')},
    );
    final container = await pumpApp(tester, bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')));
    final router = container.read(routerProvider);
    unawaited(router.push(AppRoutes.details('alpha', 'm1')));
    await tester.pumpAndSettle();

    expect(find.text('Додати в колекцію'), findsOneWidget);
    await tester.tap(find.byKey(const Key('collectionButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'На потім'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'На потім'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collectionButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Високий'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Високий')).selected, isTrue);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    router.go(AppRoutes.collection);
    await tester.pumpAndSettle();
    expect(find.text('На потім  1', findRichText: true), findsOneWidget);
    expect(find.widgetWithText(ContentCard, 'Shadows'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Нічого не знайдено'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sha');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ContentCard, 'Shadows'), findsOneWidget);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.text('Продовжити  1', findRichText: true), findsOneWidget);
  });

  testAppWidgets('tv: D-pad leaves the search field to the rows, filters and rail', (tester) async {
    final container = await pumpApp(tester, deviceClass: DeviceClass.tv);
    await tester.runAsync(
      () => container
          .read(collectionItemsProvider.notifier)
          .save(
            const CollectionItem(
              id: 'm1',
              supplier: 'alpha',
              title: 'Shadows',
              image: '',
              status: CollectionStatus.latter,
            ),
          ),
    );
    container.read(routerProvider).go(AppRoutes.collection);
    await tester.pumpAndSettle();

    FocusNode? primary() => FocusManager.instance.primaryFocus;
    T? focusedIn<T extends Widget>() => primary()?.context?.findAncestorWidgetOfExactType<T>();
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusedIn<TextField>(), isNotNull);
    await press(LogicalKeyboardKey.arrowDown);
    expect(focusedIn<ContentCard>()?.info.title, 'Shadows');

    await press(LogicalKeyboardKey.arrowUp);
    expect(focusedIn<IconButton>()?.key, const Key('rowPickRandom'), reason: 'row actions sit between');
    await press(LogicalKeyboardKey.arrowUp);
    expect(focusedIn<TextField>(), isNotNull, reason: 'up from the first row returns to the field');

    await press(LogicalKeyboardKey.arrowRight);
    expect(focusedIn<IconButton>()?.key, const Key('collectionFiltersButton'));

    await press(LogicalKeyboardKey.arrowLeft);
    expect(focusedIn<TextField>(), isNotNull);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(focusedIn<NavigationRail>(), isNotNull);
  });

  testAppWidgets('empty collection page', (tester) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go(AppRoutes.collection);
    await tester.pumpAndSettle();
    expect(find.textContaining('Колекція порожня'), findsOneWidget);
  });

  testAppWidgets('picker at startup with two profiles; choosing one opens home', (tester) async {
    final prefs = await createTestPreferences();
    final now = DateTime(2026);
    final profiles = [
      Profile(id: 'p1', name: 'Мама', colorSeed: profileColors[0], createdAt: now),
      Profile(id: 'p2', name: 'Тато', colorSeed: profileColors[1], createdAt: now),
    ];
    await prefs.setString(AppPreferences.profiles, jsonEncode([for (final p in profiles) p.toJson()]));

    final container = await pumpApp(tester, prefs: prefs);
    final router = container.read(routerProvider);
    expect(router.state.uri.path, AppRoutes.profiles);
    expect(find.text('Хто дивиться?'), findsOneWidget);

    await tester.tap(find.text('Тато'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.home);
    expect(container.read(activeProfileIdProvider), 'p2');
  });

  testAppWidgets('manage profiles: add and delete with confirmation', (tester) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go(AppRoutes.settingsProfiles);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Додати профіль'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profileNameField')), 'Діти');
    await tester.pump();
    await tester.tap(find.text('Зберегти'));
    await tester.pumpAndSettle();
    expect(find.text('Діти'), findsOneWidget);
    expect(container.read(profilesProvider), hasLength(2));

    final deleteButtons = find.byTooltip('Видалити профіль');
    expect(
      tester.widget<IconButton>(find.ancestor(of: deleteButtons.first, matching: find.byType(IconButton))).onPressed,
      isNull,
      reason: 'active profile',
    );
    await tester.tap(deleteButtons.last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Видалити профіль'));
    await tester.pumpAndSettle();
    expect(find.text('Діти'), findsNothing);
    expect(container.read(profilesProvider), hasLength(1));
  });

  testAppWidgets('account dialog shows the active profile and opens the picker', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
    expect(find.text('Основний'), findsOneWidget);

    await tester.tap(find.text('Змінити профіль'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.profiles);
  });
}
