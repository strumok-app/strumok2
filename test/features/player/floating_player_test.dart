import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/theme.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/player/domain/floating_layout.dart';
import 'package:strumok/features/player/presentation/controls/desktop/desktop_controls.dart';
import 'package:strumok/features/player/presentation/controls/mobile/mobile_controls.dart';
import 'package:strumok/features/player/presentation/floating_player.dart';
import 'package:strumok/features/player/presentation/player_controller.dart';
import 'package:strumok/features/player/presentation/widgets/compact_player_controls.dart';
import 'package:strumok/features/player/presentation/widgets/player_widgets.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('floating layout', () {
    const area = Size(1000, 600);
    const player = Size(200, 100);

    test('corners keep the edge distances', () {
      Offset at(FloatingCorner corner) =>
          floatingCornerOffset(corner, area: area, player: player, horizontal: 16, vertical: 32);
      expect(at(FloatingCorner.topLeft), const Offset(16, 32));
      expect(at(FloatingCorner.topRight), const Offset(784, 32));
      expect(at(FloatingCorner.bottomLeft), const Offset(16, 468));
      expect(at(FloatingCorner.bottomRight), const Offset(784, 468));
    });

    test('an area smaller than the player pins it to the top-left distance', () {
      final offset = floatingCornerOffset(
        FloatingCorner.bottomRight,
        area: const Size(100, 50),
        player: player,
        horizontal: 10,
        vertical: 10,
      );
      expect(offset, const Offset(10, 10));
    });

    test('snaps to the corner of the quarter holding the center', () {
      expect(nearestFloatingCorner(const Offset(100, 100), area), FloatingCorner.topLeft);
      expect(nearestFloatingCorner(const Offset(900, 100), area), FloatingCorner.topRight);
      expect(nearestFloatingCorner(const Offset(100, 500), area), FloatingCorner.bottomLeft);
      expect(nearestFloatingCorner(const Offset(900, 500), area), FloatingCorner.bottomRight);
    });
  });

  late List<FakeVideoBackend> backends;
  FakeVideoBackend backend() => backends.last;

  Future<ProviderContainer> openPlayer(
    WidgetTester tester, {
    DeviceClass deviceClass = DeviceClass.desktop,
    Map<String, Object> prefs = const {},
    Size size = const Size(1280, 720),
  }) async {
    backends = [];
    final details = FakeDetails(
      'alpha',
      'm1',
      title: 'Movie',
      loadItems: () async => [
        for (var n = 0; n < 3; n++)
          FakeMediaItem(n, 'Episode ${n + 1}', sourceList: [FakeVideoSource('A', url: 'https://a.example/$n.m3u8')]),
      ],
    );
    final container = await pumpApp(
      tester,
      size: size,
      deviceClass: deviceClass,
      prefs: await createTestPreferences(prefs),
      bundle: SupplierBundleReady(
        FakeBundle([
          FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () {
        final created = FakeVideoBackend();
        backends.add(created);
        return created;
      },
    );
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1')));
    await tester.pumpAndSettle();
    return container;
  }

  /// Lets work outside the fake clock (collection store) finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
  }

  Future<void> leavePlayer(WidgetTester tester, ProviderContainer container) async {
    container.read(routerProvider).pop();
    await settle(tester);
  }

  final floating = find.byKey(const Key('floatingPlayer'));

  testAppWidgets('desktop: leaving a playing video keeps it in the mini player', (tester) async {
    final container = await openPlayer(tester);
    expect(floating, findsNothing, reason: 'not while the full player is shown');

    await leavePlayer(tester, container);
    expect(floating, findsOneWidget);
    expect(find.byType(DesktopControls), findsNothing);
    expect(find.descendant(of: floating, matching: find.byKey(const Key('fakeVideo'))), findsOneWidget);
    expect(backend().disposed, isFalse);
    expect(container.read(playerControllerProvider), isNotNull);
  });

  testAppWidgets('desktop: 420 wide, 16:9, bottom-right 10 from the edges', (tester) async {
    final container = await openPlayer(tester);
    await leavePlayer(tester, container);
    final rect = tester.getRect(floating);
    expect(rect.size, const Size(420, 420 * 9 / 16));
    expect(rect.bottomRight, const Offset(1270, 710));
  });

  testAppWidgets('phone: 220 wide with controls always visible, 16/32 from the edges', (tester) async {
    final container = await openPlayer(tester, deviceClass: DeviceClass.phone, size: const Size(400, 800));
    await leavePlayer(tester, container);
    final rect = tester.getRect(floating);
    expect(rect.size, const Size(220, 220 * 9 / 16));
    expect(rect.bottomRight, const Offset(384, 768));
    expect(find.byKey(const Key('floatingPlayPause')), findsOneWidget);
    expect(find.byKey(const Key('floatingClose')), findsOneWidget);
  });

  testAppWidgets('desktop: the PiP window controls, shown on hover and hidden after 2 s', (tester) async {
    final container = await openPlayer(tester);
    await leavePlayer(tester, container);
    final playPause = find.byKey(const Key('playPauseButton'));
    expect(find.byType(CompactPlayerControls), findsOneWidget);
    expect(find.byKey(const Key('floatingPlayPause')), findsNothing, reason: 'touch controls are mobile only');
    expect(
      tester.widget<IgnorePointer>(find.ancestor(of: playPause, matching: find.byType(IgnorePointer)).first).ignoring,
      isTrue,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(floating) + const Offset(0, 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(CompactPlayerControls.expandKey).hitTestable(), findsOneWidget);
    expect(find.byKey(CompactPlayerControls.closeKey).hitTestable(), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous).hitTestable(), findsOneWidget, reason: 'prev / play / next in the center');

    await tester.tap(playPause);
    await tester.pump();
    expect(backend().calls.last, 'playOrPause');
    expect(backend().status.value.playing, isFalse);

    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(CompactPlayerControls.expandKey).hitTestable(), findsNothing);
  });

  testAppWidgets('desktop: a click shows the controls; expand reopens the full player without reloading', (
    tester,
  ) async {
    final container = await openPlayer(tester);
    final opened = backend().opened.length;
    await leavePlayer(tester, container);

    await tester.tap(floating);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DesktopControls), findsNothing, reason: 'a click does not open the player');
    await tester.tap(find.byKey(CompactPlayerControls.expandKey));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopControls), findsOneWidget);
    expect(floating, findsNothing);
    expect(backends, hasLength(1), reason: 'same backend instance');
    expect(backend().opened, hasLength(opened), reason: 'no re-buffering');
    expect(backend().disposed, isFalse);
  });

  testAppWidgets('desktop: close stops playback', (tester) async {
    final container = await openPlayer(tester);
    await leavePlayer(tester, container);
    await tester.tap(floating);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(CompactPlayerControls.closeKey));
    await settle(tester);
    expect(floating, findsNothing);
    expect(backend().disposed, isTrue);
  });

  testAppWidgets('phone: tap reopens the full player', (tester) async {
    final container = await openPlayer(tester, deviceClass: DeviceClass.phone, size: const Size(400, 800));
    await leavePlayer(tester, container);
    expect(find.byType(CompactPlayerControls), findsNothing);

    await tester.tap(floating);
    await tester.pumpAndSettle();
    expect(find.byType(MobileControls), findsOneWidget);
    expect(backends, hasLength(1));
  });

  testAppWidgets('drag snaps to the nearest corner', (tester) async {
    final container = await openPlayer(tester);
    await leavePlayer(tester, container);

    await tester.drag(floating, const Offset(-900, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(floating), const Offset(10, 10));

    await tester.drag(floating, const Offset(800, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(floating).topRight, const Offset(1270, 10));
  });

  testAppWidgets('stays above other routes', (tester) async {
    final container = await openPlayer(tester);
    await leavePlayer(tester, container);
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();
    expect(floating, findsOneWidget);
  });

  testAppWidgets('close stops playback', (tester) async {
    final container = await openPlayer(tester, deviceClass: DeviceClass.phone, size: const Size(400, 800));
    await leavePlayer(tester, container);

    await tester.tap(find.byKey(const Key('floatingClose')));
    await settle(tester);
    expect(floating, findsNothing);
    expect(backend().disposed, isTrue);
    expect(container.read(playerControllerProvider), isNull);
    expect(container.read(floatingPlayerProvider), isFalse);
  });

  testAppWidgets('a paused video floats too and stays paused', (tester) async {
    final container = await openPlayer(tester);
    await container.read(playerControllerProvider.notifier).pause();
    await leavePlayer(tester, container);
    expect(floating, findsOneWidget);
    expect(backend().disposed, isFalse);
    expect(backend().status.value.playing, isFalse);
  });

  testAppWidgets('a failed session is stopped when leaving', (tester) async {
    final container = await openPlayer(tester);
    backend().fail('boom');
    await tester.pumpAndSettle();
    await leavePlayer(tester, container);
    expect(floating, findsNothing);
    expect(backend().disposed, isTrue);
  });

  testAppWidgets('setting off: leaving stops playback', (tester) async {
    final container = await openPlayer(tester, prefs: {AppPreferences.floatingVideoPlayerEnabled: false});
    await leavePlayer(tester, container);
    expect(floating, findsNothing);
    expect(backend().disposed, isTrue);
  });

  testAppWidgets('tv: never floats', (tester) async {
    final container = await openPlayer(tester, deviceClass: DeviceClass.tv);
    await leavePlayer(tester, container);
    expect(floating, findsNothing);
    expect(backend().disposed, isTrue);
  });

  testAppWidgets('opening another title replaces the floating session', (tester) async {
    final container = await openPlayer(tester);
    await leavePlayer(tester, container);
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1', item: 2)));
    await tester.pumpAndSettle();
    expect(floating, findsNothing);
    expect(backends, hasLength(1));
    expect(backend().opened.last.link.toString(), 'https://a.example/2.m3u8', reason: 'the requested episode');
  });

  testAppWidgets('settings sheet: floating player switch, persisted', (tester) async {
    final container = await openPlayer(tester);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-floating'));
    await tester.scrollUntilVisible(row, 100, scrollable: find.byType(Scrollable).last);
    expect(tester.widget<SwitchListTile>(row).value, isTrue);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(row).value, isFalse);
    expect(container.read(appPreferencesProvider).getBool(AppPreferences.floatingVideoPlayerEnabled), isFalse);
  });

  testAppWidgets('tv: no floating player switch', (tester) async {
    await openPlayer(tester, deviceClass: DeviceClass.tv);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-shuffle'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-floating'), skipOffstage: false), findsNothing);
  });

  testAppWidgets('controls and mini player use the dark player theme; side sheets keep the app theme', (tester) async {
    final container = await openPlayer(
      tester,
      prefs: {AppPreferences.themeBrightness: 'light', AppPreferences.themeColorScheme: 'monochrome'},
    );
    final dark = buildColorScheme(AppColorScheme.monochrome, Brightness.dark);
    final controls = Theme.of(tester.element(find.byType(PlayerSeekBar)));
    expect(controls.brightness, Brightness.dark);
    expect(controls.colorScheme.primary, dark.primary, reason: 'light accents on video, not black');

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byKey(const ValueKey('settings-speed')))).brightness, Brightness.light);
    await tester.tapAt(const Offset(10, 360));
    await tester.pumpAndSettle();

    await leavePlayer(tester, container);
    expect(Theme.of(tester.element(find.byKey(const Key('floatingPlayer')))).brightness, Brightness.dark);
  });

  testAppWidgets('desktop: hovering in and out while loading keeps semantics consistent', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await openPlayer(tester);
    backend().status.value = backend().status.value.copyWith(buffering: true);
    container.read(routerProvider).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(seconds: 1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final rect = tester.getRect(floating);
    for (final target in [rect.topLeft + const Offset(28, 28), rect.topRight + const Offset(-28, 28), rect.center]) {
      await mouse.moveTo(target);
      await tester.pump(const Duration(seconds: 2));
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 100));
      await mouse.moveTo(target);
      await tester.pump(const Duration(seconds: 4));
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
