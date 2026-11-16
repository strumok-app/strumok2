import 'dart:async';

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

void main() {
  const size = Size(960, 540);
  late FakeVideoBackend backend;

  Future<ProviderContainer> openPlayer(WidgetTester tester) async {
    final items = [
      for (var n = 0; n < 3; n++)
        FakeMediaItem(
          n,
          'Episode ${n + 1}',
          sourceList: [
            FakeVideoSource('A', url: 'https://a.example/$n.m3u8'),
            FakeVideoSource('B'),
          ],
        ),
    ];
    final details = FakeDetails('alpha', 'm1', title: 'Movie', loadItems: () async => items);
    final container = await pumpApp(
      tester,
      size: size,
      deviceClass: DeviceClass.tv,
      bundle: SupplierBundleReady(
        FakeBundle([
          FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () => backend = FakeVideoBackend(),
    );
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1')));
    await tester.pumpAndSettle();
    backend.emit(position: const Duration(minutes: 5), duration: const Duration(minutes: 20));
    await tester.pump();
    return container;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  /// Playback is on, so the controls auto-hide.
  Future<void> waitHidden(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  bool hasFocus(WidgetTester tester, Finder finder) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    final target = tester.element(finder);
    if (focused == target) return true;
    var found = false;
    focused.visitAncestorElements((element) {
      found = element == target;
      return !found;
    });
    return found;
  }

  double overlayOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: find.byKey(const Key('tvSeekBar')), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  final play = find.byKey(const Key('playPauseButton'));
  final seekBar = find.byKey(const Key('tvSeekBar'));

  testAppWidgets('hidden: OK toggles playback; ←/→ accumulate a preview and seek once after 500 ms', (tester) async {
    await openPlayer(tester);
    await waitHidden(tester);
    backend.calls.clear();

    await press(tester, LogicalKeyboardKey.select);
    expect(backend.calls, ['playOrPause']);
    expect(overlayOpacity(tester), 0, reason: 'OK does not reveal the controls');
    backend.calls.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(backend.calls, isEmpty, reason: 'debounced');
    expect(find.byKey(const Key('tvSeekPreview')), findsOneWidget);
    expect(find.textContaining('5:20'), findsOneWidget);
    expect(find.textContaining('+20'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(backend.calls, ['seek:320']);
    expect(find.byKey(const Key('tvSeekPreview')), findsNothing);
    expect(overlayOpacity(tester), 0, reason: 'seeking while hidden keeps the controls hidden');
  });

  testAppWidgets('↑/↓ reveal the controls on Play; focus traverses both bars', (tester) async {
    await openPlayer(tester);
    await waitHidden(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(overlayOpacity(tester), 1);
    expect(hasFocus(tester, play), isTrue);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(hasFocus(tester, find.byTooltip('Наступний')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(hasFocus(tester, seekBar), isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(hasFocus(tester, play), isTrue, reason: 'down from the bar lands on Play');

    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(hasFocus(tester, seekBar), isTrue, reason: 'the top bar is title only');
    expect(find.byType(BackButton), findsNothing);
  });

  testAppWidgets('focused seek bar: ←/→ move by 10 s with the debounced preview', (tester) async {
    await openPlayer(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(hasFocus(tester, seekBar), isTrue);
    backend.calls.clear();

    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(backend.calls, isEmpty);
    expect(find.textContaining('4:40'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    expect(backend.calls, ['seek:280']);
    expect(hasFocus(tester, seekBar), isTrue, reason: 'seeking does not move focus');
  });

  testAppWidgets('auto-hide moves focus back, so OK toggles playback instead of a hidden button', (tester) async {
    await openPlayer(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(hasFocus(tester, find.byTooltip('Наступний')), isTrue);

    await waitHidden(tester);
    expect(overlayOpacity(tester), 0);
    backend.calls.clear();
    await press(tester, LogicalKeyboardKey.select);
    expect(backend.calls, ['playOrPause']);
  });

  testAppWidgets('Back hides the controls first, then leaves the player', (tester) async {
    final container = await openPlayer(tester);
    final router = container.read(routerProvider);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(overlayOpacity(tester), 1);

    // The simulator has no Android scan code for Back; the web key map carries the same logical key.
    await tester.sendKeyEvent(LogicalKeyboardKey.goBack, platform: 'web', physicalKey: PhysicalKeyboardKey.browserBack);
    await tester.pumpAndSettle();
    expect(overlayOpacity(tester), 0);
    expect(router.state.uri.path, '/video/alpha/m1');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.home);
  });

  testAppWidgets('Playlist opens from the controls; choosing an episode switches to it', (tester) async {
    final container = await openPlayer(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(hasFocus(tester, find.byTooltip('Джерело')), isTrue, reason: 'source sits in the bottom row');
    expect(find.text('Джерело'), findsOneWidget, reason: 'the focused button shows its label');
    expect(find.text('Епізоди'), findsNothing);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(hasFocus(tester, find.byTooltip('Епізоди')), isTrue);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mediaItem-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mediaItem-2')));
    await tester.pumpAndSettle();
    expect(container.read(playerControllerProvider)!.itemIndex, 2);
  });

  testAppWidgets('failure focuses Retry', (tester) async {
    await openPlayer(tester);
    await waitHidden(tester);
    backend.fail('boom');
    await tester.pumpAndSettle();
    expect(hasFocus(tester, find.widgetWithText(FilledButton, 'Повторити')), isTrue);
  });
}
