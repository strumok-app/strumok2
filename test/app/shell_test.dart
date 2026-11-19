import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/shell/app_shell.dart';
import 'package:strumok/app/shell/shell_page.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/home/presentation/home_page.dart';
import 'package:strumok/features/settings/presentation/settings_page.dart';

import '../helpers/test_app.dart';

void main() {
  const phone = Size(400, 800);
  const desktop = Size(1280, 720);

  testAppWidgets('narrow layout uses bottom navigation', (tester) async {
    await pumpApp(tester, size: phone, deviceClass: DeviceClass.phone);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
    expect(find.byTooltip('Головна'), findsOneWidget);
    expect(find.byTooltip('Пошук'), findsOneWidget);
  });

  testAppWidgets('narrow layout is compact: no top bar, 50 dp bar with the account menu', (tester) async {
    final container = await pumpApp(tester, size: phone, deviceClass: DeviceClass.phone);

    expect(find.byType(AppBar), findsNothing);
    expect(tester.getSize(find.byType(NavigationBar)).height, bottomNavHeight);
    final account = find.byKey(const Key('accountMenuButton'));
    expect(find.descendant(of: find.byType(NavigationBar), matching: account), findsOneWidget);

    await tester.tap(account);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Налаштування'));
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.uri.path, AppRoutes.settings);
    expect(find.byType(BackButton), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0, reason: 'account destination is never selected');
  });

  testAppWidgets('wide layout uses navigation rail', (tester) async {
    await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.labelType, NavigationRailLabelType.none);
    expect(find.byTooltip('Головна'), findsOneWidget);
    expect(find.byTooltip('Пошук'), findsOneWidget);
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

  testAppWidgets('each shell page paints ink on its own Material, so covered pages cannot show through', (
    tester,
  ) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();

    final home = tester.element(find.byType(HomePage, skipOffstage: false));
    final settings = tester.element(find.byType(SettingsPage));
    expect(Material.of(home), isNot(same(Material.of(settings))));
  });

  testWidgets('mobile back transition keeps the surface behind the outgoing page content', (tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final captureKey = GlobalKey();
    const markerKey = Key('surfaceMarker');
    const surface = Color(0xFFEEEEEE);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ColoredBox(color: Colors.red),
        ),
        GoRoute(
          path: '/details',
          pageBuilder: (_, state) => ShellPage(
            state: state,
            child: const Center(
              child: SizedBox.square(
                key: markerKey,
                dimension: 40,
                child: ColoredBox(color: surface),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp.router(
          theme: ThemeData(
            platform: TargetPlatform.android,
            colorScheme: const ColorScheme.light(surface: surface),
          ),
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push('/details'));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(markerKey), findsOneWidget, reason: 'sample while the outgoing page is still visible');
    final center = tester.getCenter(find.byKey(markerKey));
    final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    });
    int pixelAt(Offset point) => pixels!.getUint32((point.dy.floor() * phone.width.toInt() + point.dx.floor()) * 4);
    expect(pixelAt(center + const Offset(40, 0)), pixelAt(center), reason: 'no underlying page bleeds through');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
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

  testAppWidgets('tv: arrows move focus between page content and the nav rail', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.tv);
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();

    bool inRail() =>
        FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<NavigationRail>() != null;

    Focus.of(tester.element(find.text('Українська'))).requestFocus();
    await tester.pump();
    expect(inRail(), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(inRail(), isTrue, reason: 'left from the page edge reaches the rail');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(inRail(), isFalse, reason: 'right from the rail returns to the page');
  });

  testAppWidgets('escape closes the account dialog before popping', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.desktop);
    final router = container.read(routerProvider);
    unawaited(router.push(AppRoutes.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(router.state.uri.path, AppRoutes.settings);
  });

  testAppWidgets('tv: account dialog is operable with keys only', (tester) async {
    final container = await pumpApp(tester, size: desktop, deviceClass: DeviceClass.tv);

    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
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

  group('android predictive back gesture pops only the visible route', () {
    Future<void> swipeBack(WidgetTester tester) async {
      Future<void> send(String method, [Map<String, Object?>? arguments]) =>
          tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            SystemChannels.backGesture.name,
            SystemChannels.backGesture.codec.encodeMethodCall(MethodCall(method, arguments)),
            (_) {},
          );
      Map<String, Object?> event(double progress) => {
        'touchOffset': [5.0, 300.0],
        'progress': progress,
        'swipeEdge': 0,
      };
      await send('startBackGesture', event(0));
      await tester.pump();
      await send('updateBackGestureProgress', event(0.5));
      await tester.pump();
      await send('commitBackGesture');
      await tester.pumpAndSettle();
    }

    Future<GoRouter> openSettings(WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = await pumpApp(tester, size: phone, deviceClass: DeviceClass.phone);
      final router = container.read(routerProvider);
      unawaited(router.push(AppRoutes.settings));
      await tester.pumpAndSettle();
      return router;
    }

    for (final (name, location) in [
      ('player', AppRoutes.video('dummy', '1')),
      ('reader', AppRoutes.manga('dummy', '1')),
    ]) {
      testAppWidgets('$name closes in one swipe, the shell page below stays', (tester) async {
        final router = await openSettings(tester);
        unawaited(router.push(location));
        await tester.pumpAndSettle();

        await swipeBack(tester);
        expect(router.state.uri.path, AppRoutes.settings);
        expect(find.byType(SettingsPage), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testAppWidgets('dialog over a shell page closes in one swipe, the page stays', (tester) async {
      final router = await openSettings(tester);
      await tester.tap(find.byKey(const Key('accountMenuButton')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      await swipeBack(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(router.state.uri.path, AppRoutes.settings);
      debugDefaultTargetPlatformOverride = null;
    });

    testAppWidgets('shell page still pops with the gesture', (tester) async {
      final router = await openSettings(tester);
      await swipeBack(tester);
      expect(router.state.uri.path, AppRoutes.home);
      debugDefaultTargetPlatformOverride = null;
    });
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
