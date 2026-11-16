import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/player/presentation/widgets/player_widgets.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  const size = Size(800, 400);
  late FakeVideoBackend backend;
  late FakeBrightnessControl brightness;
  late FakeVolumeControl volume;
  late List<MethodCall> systemCalls;

  Future<ProviderContainer> openPlayer(WidgetTester tester) async {
    systemCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    brightness = FakeBrightnessControl(0.5);
    volume = FakeVolumeControl(0.5);
    final items = [
      for (var n = 0; n < 2; n++)
        FakeMediaItem(n, 'Episode ${n + 1}', sourceList: [FakeVideoSource('A', url: 'https://a.example/$n.m3u8')]),
    ];
    final details = FakeDetails('alpha', 'm1', title: 'Movie', loadItems: () async => items);
    final container = await pumpApp(
      tester,
      size: size,
      deviceClass: DeviceClass.phone,
      bundle: SupplierBundleReady(
        FakeBundle([
          FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () => backend = FakeVideoBackend(),
      brightness: brightness,
      volume: volume,
    );
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1')));
    await tester.pumpAndSettle();
    backend.emit(position: const Duration(minutes: 5), duration: const Duration(minutes: 20));
    await tester.pump();
    return container;
  }

  double overlayOpacity(WidgetTester tester, Key key) => tester
      .widget<AnimatedOpacity>(find.ancestor(of: find.byKey(key), matching: find.byType(AnimatedOpacity)).first)
      .opacity;

  Future<void> doubleTapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(at);
    await tester.pump();
  }

  Future<void> verticalDrag(WidgetTester tester, Offset from, double dy) async {
    final gesture = await tester.startGesture(from);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, dy / 10));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  final left = Offset(size.width * 0.2, size.height / 2);
  final right = Offset(size.width * 0.8, size.height / 2);

  testAppWidgets('landscape + immersive while open; restored with brightness on exit', (tester) async {
    final container = await openPlayer(tester);
    final orientations = systemCalls.where((c) => c.method == 'SystemChrome.setPreferredOrientations');
    expect(orientations.last.arguments, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
    expect(
      systemCalls.where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode').last.arguments,
      'SystemUiMode.immersiveSticky',
    );

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(orientations.last.arguments, isEmpty);
    expect(
      systemCalls.where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode').last.arguments,
      'SystemUiMode.edgeToEdge',
    );
    expect(brightness.resets, 1);
  });

  testAppWidgets('tap toggles the controls', (tester) async {
    await openPlayer(tester);
    expect(overlayOpacity(tester, const Key('lockButton')), 1);

    await tester.tapAt(left);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(overlayOpacity(tester, const Key('lockButton')), 0);

    await tester.tapAt(left);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(overlayOpacity(tester, const Key('lockButton')), 1);
  });

  testAppWidgets('double-tap halves seek ±10 s and the indicator accumulates', (tester) async {
    await openPlayer(tester);
    backend.calls.clear();

    await doubleTapAt(tester, right);
    await tester.pump(kDoubleTapMinTime);
    await doubleTapAt(tester, right);
    expect(backend.calls, ['seek:310', 'seek:320']);
    expect(find.text('+20 с'), findsOneWidget);
    final indicator = tester.getRect(find.byKey(const Key('seekIndicator')));
    expect(indicator.height, size.height, reason: 'full height');
    expect(indicator.width, closeTo(size.width / 3, 0.01));
    expect(indicator.right, size.width, reason: 'on the tapped side');

    await tester.pump(const Duration(milliseconds: 100));
    await doubleTapAt(tester, left);
    expect(backend.calls.last, 'seek:310');
    expect(find.text('−10 с'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('seekIndicator')), findsNothing);
  });

  testAppWidgets('vertical drag: left half brightness, right half volume', (tester) async {
    await openPlayer(tester);

    await verticalDrag(tester, left, -size.height * 0.4);
    expect(brightness.value, 1, reason: 'up on the left half brightens (clamped)');
    expect(find.byKey(const Key('brightnessIndicator')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('brightnessIndicator')), findsNothing);

    await verticalDrag(tester, right, size.height * 0.12);
    expect(volume.value, inExclusiveRange(0.2, 0.5), reason: 'down on the right half lowers the volume');
    expect(find.byKey(const Key('volumeIndicator')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testAppWidgets('seek bar: thick, no thumb, flush with the bottom and side edges; buttons sit above it', (
    tester,
  ) async {
    await openPlayer(tester);
    final bar = find.byKey(const Key('seekBar'));
    final theme = tester.widget<SliderTheme>(find.ancestor(of: bar, matching: find.byType(SliderTheme)).first).data;
    expect(theme.thumbShape, SliderComponentShape.noThumb);
    expect(theme.trackHeight, PlayerSeekBar.edgeTrackHeight);

    final rect = tester.getRect(bar);
    expect(rect.bottom, size.height);
    expect(rect.left, 0);
    expect(rect.right, size.width);

    final playlist = tester.getRect(find.byTooltip('Епізоди'));
    final trackTop = size.height - PlayerSeekBar.edgeTrackHeight;
    expect(playlist.bottom, lessThanOrEqualTo(trackTop), reason: 'episodes button is in the bottom row');
    expect(trackTop - playlist.bottom, lessThanOrEqualTo(8), reason: 'no big gap above the track');
    expect(playlist.center.dx, greaterThan(size.width / 2));
    expect(
      tester.getCenter(find.byKey(const Key('playPauseButton'))),
      size.center(Offset.zero),
      reason: 'center buttons sit at the exact screen center',
    );

    backend.calls.clear();
    await tester.tapAt(Offset(size.width / 2, playlist.bottom - 4));
    // The double-tap recognizer holds the arena until its timeout.
    await tester.pump(const Duration(milliseconds: 400));
    expect(backend.calls, ['seek:600'], reason: 'touches between the buttons reach the seek bar');
  });

  testAppWidgets('horizontal swipe seeks on release and shows the target', (tester) async {
    await openPlayer(tester);
    backend.calls.clear();

    final gesture = await tester.startGesture(Offset(size.width * 0.3, size.height / 2));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(size.width * 0.05, 0));
      await tester.pump();
    }
    expect(find.byKey(const Key('swipeSeekIndicator')), findsOneWidget);
    final indicator = tester.getRect(find.byKey(const Key('swipeSeekIndicator')));
    expect(indicator.top, greaterThan(tester.getRect(find.byKey(const Key('playPauseButton'))).bottom));
    expect(indicator.bottom, lessThan(tester.getRect(find.byTooltip('Епізоди')).top), reason: 'above the bottom row');
    expect(indicator.height, lessThan(50), reason: 'one line');
    expect(backend.calls, isEmpty, reason: 'seeks only on release');
    await gesture.up();
    await tester.pump();

    // Half the width is ~60 s (minus the drag slop) after 5:00.
    final seek = backend.calls.single;
    expect(seek, startsWith('seek:3'));
    expect(int.parse(seek.split(':').last), inInclusiveRange(350, 360));
    expect(find.byKey(const Key('swipeSeekIndicator')), findsNothing);
  });

  testAppWidgets('dragging the seek bar shows the swipe indicator and seeks on release', (tester) async {
    await openPlayer(tester);
    backend.calls.clear();

    final gesture = await tester.startGesture(Offset(size.width * 0.25, size.height - 3));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(size.width * 0.05, 0));
      await tester.pump();
    }
    expect(find.byKey(const Key('swipeSeekIndicator')), findsOneWidget);
    expect(find.textContaining('10:00'), findsOneWidget, reason: 'half of 20:00');
    expect(find.textContaining('+300'), findsOneWidget, reason: 'offset from 5:00');
    expect(find.byKey(const Key('seekHoverTime')), findsNothing);
    expect(backend.calls, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(backend.calls, ['seek:600']);
    expect(find.byKey(const Key('swipeSeekIndicator')), findsNothing);
  });

  testAppWidgets('lock leaves only the unlock button and disables gestures', (tester) async {
    await openPlayer(tester);
    await tester.tap(find.byKey(const Key('lockButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lockButton')), findsNothing);
    expect(find.byKey(const Key('unlockButton')), findsOneWidget);

    backend.calls.clear();
    await doubleTapAt(tester, right);
    await verticalDrag(tester, left, -size.height * 0.3);
    await tester.pump(const Duration(seconds: 1));
    expect(backend.calls, isEmpty);
    expect(brightness.value, 0.5);

    await tester.tap(find.byKey(const Key('unlockButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lockButton')), findsOneWidget);
  });
}
