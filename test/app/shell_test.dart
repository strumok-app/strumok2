import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/device_class.dart';

import '../helpers/test_app.dart';

void main() {
  const phone = Size(400, 800);
  const desktop = Size(1280, 720);

  testAppWidgets('narrow layout uses bottom navigation', (tester) async {
    await pumpApp(tester, size: phone, deviceClass: DeviceClass.phone);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Головна'), findsWidgets);
  });

  testAppWidgets('wide layout uses navigation rail', (tester) async {
    await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testAppWidgets('nav destinations switch pages', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.search);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.collection);
  });

  testAppWidgets('account dialog opens settings with back button', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);

    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Налаштування'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(container.read(routerProvider).state.uri.path, AppRoutes.settings);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.home);
  });

  testAppWidgets('rail destinations keep their position when the back button appears', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);
    final homeIcon = find.descendant(of: find.byType(NavigationRail), matching: find.byIcon(Icons.home));
    final before = tester.getTopLeft(homeIcon);
    expect(find.byType(BackButton), findsNothing);

    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    final homeOutlined = find.descendant(of: find.byType(NavigationRail), matching: find.byIcon(Icons.home_outlined));
    expect(tester.getTopLeft(homeOutlined), before);
  });

  testAppWidgets('tv hides back button; escape pops the route', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.tv);
    final router = container.read(routerProvider);

    unawaited(router.push(AppRoutes.details('dummy', 'a/b')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/content/dummy/a%2Fb');
    expect(find.byType(BackButton), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.home);
  });

  testAppWidgets('escape closes the account dialog before popping', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);
    final router = container.read(routerProvider);
    unawaited(router.push(AppRoutes.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
    expect(find.text('Завантаження'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Завантаження'), findsNothing);
    expect(router.state.uri.path, AppRoutes.settings);
  });

  testAppWidgets('tv: account dialog is operable with keys only', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.tv);

    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(container.read(routerProvider).state.uri.path, AppRoutes.settings);
  });

  testAppWidgets('player and reader are outside the shell', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);

    container.read(routerProvider).go(AppRoutes.video('dummy', '1'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);

    container.read(routerProvider).go(AppRoutes.manga('dummy', '1'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
  });

  testAppWidgets('unknown route shows not found', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);

    container.read(routerProvider).go('/nope');
    await tester.pumpAndSettle();
    expect(find.text('Сторінку не знайдено'), findsOneWidget);
  });

  test('route paths encode segments', () {
    expect(AppRoutes.details('s', 'x y'), '/content/s/x%20y');
  });
}
