import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/player/presentation/player_controller.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

FakeMediaItem episode(int n) => FakeMediaItem(
  n,
  'Episode ${n + 1}',
  sourceList: [
    FakeVideoSource('A', url: 'https://a.example/$n.m3u8'),
    FakeVideoSource('B'),
  ],
);

void main() {
  late FakeVideoBackend backend;
  late FakeWindowFullscreen window;

  Future<ProviderContainer> openPlayer(WidgetTester tester, {DeviceClass deviceClass = DeviceClass.desktop}) async {
    window = FakeWindowFullscreen();
    final details = FakeDetails(
      'alpha',
      'm1',
      title: 'Movie',
      loadItems: () async => [episode(0), episode(1), episode(2)],
    );
    final container = await pumpApp(
      tester,
      deviceClass: deviceClass,
      bundle: SupplierBundleReady(
        FakeBundle([
          FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () => backend = FakeVideoBackend(),
      windowFullscreen: window,
    );
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1')));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  testAppWidgets('desktop: back button sits next to where the shell rail shows it', (tester) async {
    final container = await openPlayer(tester);
    final playerBack = tester.getCenter(find.byType(BackButton));

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(AppRoutes.details('alpha', 'm1')));
    await tester.pumpAndSettle();
    expect(playerBack - tester.getCenter(find.byType(BackButton)), const Offset(4, 4));
  });

  testAppWidgets('desktop: shows the video with title, episode and controls', (tester) async {
    await openPlayer(tester);
    expect(find.byKey(const Key('fakeVideo')), findsOneWidget);
    expect(find.text('Movie'), findsOneWidget);
    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.byKey(const Key('seekBar')), findsOneWidget);
    expect(backend.opened.single.link.toString(), 'https://a.example/0.m3u8');
  });

  testAppWidgets('desktop: seek bar is thin without a thumb until hovered', (tester) async {
    await openPlayer(tester);
    backend.emit(duration: const Duration(minutes: 10));
    await tester.pumpAndSettle();
    final bar = find.byKey(const Key('seekBar'));
    SliderThemeData theme() =>
        tester.widget<SliderTheme>(find.ancestor(of: bar, matching: find.byType(SliderTheme)).first).data;

    final height = tester.getSize(bar).height;
    expect(theme().thumbShape, SliderComponentShape.noThumb);
    expect(theme().overlayShape, SliderComponentShape.noOverlay);
    final thin = theme().trackHeight!;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(bar));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    expect(theme().thumbShape, isA<RoundSliderThumbShape>());
    expect(theme().trackHeight, thin * 2);
    expect(tester.getSize(bar).height, height, reason: 'controls below must not move');

    final label = find.byKey(const Key('seekHoverTime'));
    expect(
      find.descendant(of: label, matching: find.text('5:00')),
      findsOneWidget,
      reason: 'middle of 10 min',
    );
    expect(tester.getRect(label).bottom, lessThanOrEqualTo(tester.getRect(bar).top + 4), reason: 'above the bar');

    await mouse.moveTo(tester.getRect(bar).centerLeft + const Offset(2, 0));
    await tester.pumpAndSettle();
    expect(find.descendant(of: label, matching: find.text('0:00')), findsOneWidget);

    await mouse.moveTo(tester.getRect(bar).topCenter - const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(label, findsNothing);
  });

  testAppWidgets('desktop: keyboard map (spec-06 §6.6)', (tester) async {
    final container = await openPlayer(tester);
    backend.emit(position: const Duration(seconds: 100), duration: const Duration(seconds: 1000));

    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.keyI);
    await press(tester, LogicalKeyboardKey.keyJ);
    await press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
    await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(backend.calls, [
      'open:https://a.example/0.m3u8@0',
      'playOrPause',
      'seek:110',
      'seek:100',
      'seek:160',
      'seek:100',
      'frameBackStep',
      'frameStep',
      'volume:95',
    ]);

    await press(tester, LogicalKeyboardKey.bracketRight);
    expect(container.read(playerControllerProvider)!.itemIndex, 1);
    await press(tester, LogicalKeyboardKey.bracketLeft);
    expect(container.read(playerControllerProvider)!.itemIndex, 0);
  });

  testAppWidgets('desktop: F/Enter/Esc control full screen; Esc when windowed leaves the player', (tester) async {
    final container = await openPlayer(tester);
    final router = container.read(routerProvider);

    await press(tester, LogicalKeyboardKey.keyF);
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(window.changes, [true, false, true, false]);
    expect(router.state.uri.path, '/video/alpha/m1');

    await press(tester, LogicalKeyboardKey.escape);
    expect(router.state.uri.path, AppRoutes.home);
  });

  testAppWidgets('desktop: double-click toggles full screen; leaving the player restores the window', (tester) async {
    final container = await openPlayer(tester);
    final surface = find.byKey(const Key('playerSurface'));
    await tester.tap(surface);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(surface);
    await tester.pumpAndSettle();
    expect(window.changes, [true]);

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(window.changes, [true, false]);
  });

  testAppWidgets('desktop: P opens the playlist; picking an episode switches to it', (tester) async {
    final container = await openPlayer(tester);
    await press(tester, LogicalKeyboardKey.keyP);
    expect(find.text('Епізоди'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mediaItem-2')));
    await tester.pumpAndSettle();
    expect(container.read(playerControllerProvider)!.itemIndex, 2);
    expect(backend.opened.last.link.toString(), 'https://a.example/2.m3u8');
  });

  testAppWidgets('desktop: source selector switches the server', (tester) async {
    await openPlayer(tester);
    await tester.tap(find.byTooltip('Джерело'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-1')));
    await tester.pumpAndSettle();
    expect(backend.opened.last.link.toString(), 'https://cdn.example.com/B.m3u8');
  });

  testAppWidgets('playback failure offers Retry and Change source', (tester) async {
    await openPlayer(tester);
    backend.emit(position: const Duration(seconds: 30));
    backend.fail('boom');
    await tester.pumpAndSettle();
    expect(find.text('Помилка відтворення'), findsOneWidget);
    expect(find.text('Змінити джерело'), findsOneWidget);

    await tester.tap(find.text('Повторити'));
    await tester.pumpAndSettle();
    expect(find.text('Помилка відтворення'), findsNothing);
    expect(backend.opened.last.start, const Duration(seconds: 30));
  });

  testAppWidgets('tv: hidden controls; Select toggles playback, arrows reveal and focus Play', (tester) async {
    await openPlayer(tester, deviceClass: DeviceClass.tv);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.select);
    expect(backend.calls.last, 'playOrPause');

    await press(tester, LogicalKeyboardKey.arrowDown);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<IconButton>()?.key, const Key('playPauseButton'));
  });
}
