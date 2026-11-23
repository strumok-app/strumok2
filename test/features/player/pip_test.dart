import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/player/data/pip/pip.dart';
import 'package:strumok/features/player/data/pip/pip_android.dart';
import 'package:strumok/features/player/data/pip/pip_desktop.dart';
import 'package:strumok/features/player/presentation/controls/desktop/desktop_controls.dart';
import 'package:strumok/features/player/presentation/controls/mobile/mobile_controls.dart';
import 'package:strumok/features/player/presentation/pip_view.dart';
import 'package:strumok/features/player/presentation/widgets/compact_player_controls.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

class FakePipWindow implements PipWindow {
  final calls = <String>[];
  bool fullScreen;
  bool maximized;
  Rect bounds;

  FakePipWindow({
    this.fullScreen = false,
    this.maximized = false,
    this.bounds = const Rect.fromLTWH(100, 50, 1280, 720),
  });

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    calls.add('fullScreen:$value');
    fullScreen = value;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> maximize() async {
    calls.add('maximize');
    maximized = true;
  }

  @override
  Future<void> unmaximize() async {
    calls.add('unmaximize');
    maximized = false;
  }

  @override
  Future<Rect> getBounds() async => bounds;

  @override
  Future<void> setBounds(Rect value) async {
    calls.add('bounds:${value.left.round()},${value.top.round()},${value.width.round()}x${value.height.round()}');
    bounds = value;
  }

  @override
  Future<void> setSize(Size size) async {
    calls.add('size:${size.width.round()}x${size.height.round()}');
    bounds = bounds.topLeft & size;
  }

  @override
  Future<void> setFrameless(bool value) async => calls.add('frameless:$value');

  @override
  Future<void> setAlwaysOnTop(bool value) async => calls.add('onTop:$value');

  @override
  Future<void> alignBottomRight() async => calls.add('bottomRight');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('drag');
}

void main() {
  group('compact window size', () {
    test('long side 576 px with the video aspect ratio', () {
      expect(compactWindowSize(16 / 9), const Size(576, 324));
      expect(compactWindowSize(4 / 3), const Size(576, 432));
      expect(compactWindowSize(9 / 16), const Size(324, 576));
    });

    test('extreme or unknown ratios are clamped or default to 16:9', () {
      expect(compactWindowSize(5), Size(576, 576 / (21 / 9)));
      expect(compactWindowSize(0), const Size(576, 324));
      expect(compactWindowSize(double.nan), const Size(576, 324));
    });
  });

  group('desktop PiP', () {
    test('only while enabled', () async {
      final window = FakePipWindow();
      final pip = DesktopPip(window, settleDelay: Duration.zero);
      await pip.enter();
      expect(pip.isActive.value, isFalse);
      expect(window.calls, isEmpty);
    });

    test('compact always-on-top window with the video ratio; exit restores the bounds', () async {
      final window = FakePipWindow();
      final pip = DesktopPip(window, settleDelay: Duration.zero);
      await pip.enable();
      await pip.updatePlayback(const PipPlayback(aspectRatio: 4 / 3));
      await pip.enter();
      expect(pip.isActive.value, isTrue);
      expect(window.calls, ['frameless:true', 'size:576x432', 'onTop:true', 'bottomRight']);

      window.calls.clear();
      await pip.exit();
      expect(pip.isActive.value, isFalse);
      expect(window.calls, ['onTop:false', 'frameless:false', 'bounds:100,50,1280x720']);
    });

    test('leaves and restores full screen and maximized state', () async {
      final window = FakePipWindow(fullScreen: true, maximized: true);
      final pip = DesktopPip(window, settleDelay: Duration.zero);
      await pip.enable();
      await pip.enter();
      expect(window.calls.take(2), ['fullScreen:false', 'unmaximize']);

      window.calls.clear();
      await pip.disable();
      expect(window.calls, ['onTop:false', 'frameless:false', 'bounds:100,50,1280x720', 'maximize', 'fullScreen:true']);
    });

    test('transitions never interleave', () async {
      final window = FakePipWindow();
      final pip = DesktopPip(window, settleDelay: const Duration(milliseconds: 5));
      await pip.enable();
      unawaited(pip.enter());
      await pip.exit();
      expect(window.calls, [
        'frameless:true',
        'size:576x324',
        'onTop:true',
        'bottomRight',
        'onTop:false',
        'frameless:false',
        'bounds:100,50,1280x720',
      ]);
    });

    test('window drag only while in PiP', () async {
      final window = FakePipWindow();
      final pip = DesktopPip(window, settleDelay: Duration.zero);
      await pip.startWindowDrag();
      await pip.enable();
      await pip.enter();
      await pip.startWindowDrag();
      expect(window.calls.where((c) => c == 'drag'), hasLength(1));
    });
  });

  group('android PiP channel', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(AndroidPip.channel, (call) async {
        calls.add(call);
        return call.method == 'isSupported' ? true : null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(AndroidPip.channel, null));

    Future<void> fromNative(String method, Map<String, Object?> arguments) => messenger.handlePlatformMessage(
      'strumok/pip',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );

    test('spec-06 §6.10 method names and arguments', () async {
      final pip = await AndroidPip.create();
      expect(pip.isSupported, isTrue);
      await pip.enable();
      await pip.updatePlayback(
        const PipPlayback(isPlaying: true, hasNext: true, showSkipButtons: true, aspectRatio: 2),
      );
      await pip.enter();
      await pip.exit();
      await pip.disable();
      await pip.closeApp();
      expect(calls.map((c) => c.method), ['isSupported', 'enable', 'update', 'enter', 'exit', 'disable', 'closeApp']);
      expect(calls[2].arguments, {
        'isPlaying': true,
        'hasPrev': false,
        'hasNext': true,
        'showSkipButtons': true,
        'aspectRatio': 2.0,
      });
    });

    test('native mode changes and remote actions', () async {
      final pip = await AndroidPip.create();
      final actions = <PipAction>[];
      final subscription = pip.actions.listen(actions.add);
      addTearDown(subscription.cancel);

      await fromNative('onPipModeChanged', {'active': true});
      expect(pip.isActive.value, isTrue);
      for (final action in ['playPause', 'next', 'prev', 'dismissed', 'unknown']) {
        await fromNative('onAction', {'action': action});
      }
      await fromNative('onPipModeChanged', {'active': false});
      await pumpEventQueue();
      expect(pip.isActive.value, isFalse);
      expect(actions, PipAction.values);
    });

    test('unsupported device: nothing but the support check is sent', () async {
      messenger.setMockMethodCallHandler(AndroidPip.channel, (call) async {
        calls.add(call);
        return false;
      });
      final pip = await AndroidPip.create();
      await pip.enable();
      await pip.enter();
      expect(pip.isSupported, isFalse);
      expect(calls.map((c) => c.method), ['isSupported']);
    });
  });

  group('player', () {
    late List<FakeVideoBackend> backends;
    late FakePip pip;
    FakeVideoBackend backend() => backends.last;

    Future<ProviderContainer> openPlayer(
      WidgetTester tester, {
      DeviceClass deviceClass = DeviceClass.desktop,
      bool supported = true,
    }) async {
      backends = [];
      pip = FakePip(supported: supported);
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
        deviceClass: deviceClass,
        size: deviceClass == DeviceClass.phone ? const Size(800, 400) : const Size(1280, 720),
        pip: pip,
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

    testAppWidgets('allowed only while the player is shown; playback state is mirrored', (tester) async {
      final container = await openPlayer(tester);
      expect(pip.calls, ['enable']);
      backend().status.value = backend().status.value.copyWith(aspectRatio: 2);
      expect(
        pip.playbacks.last,
        const PipPlayback(isPlaying: true, hasNext: true, showSkipButtons: true, aspectRatio: 2),
      );

      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(pip.calls, ['enable', 'disable']);
      expect(pip.playbacks.last, const PipPlayback(), reason: 'no auto-enter with a stale playing state');
    });

    testAppWidgets('remote actions drive the player', (tester) async {
      await openPlayer(tester);
      pip.action(PipAction.next);
      await tester.pumpAndSettle();
      expect(backend().opened.last.link.toString(), 'https://a.example/1.m3u8');
      expect(pip.playbacks.last.hasPrev, isTrue);

      pip.action(PipAction.prev);
      await tester.pumpAndSettle();
      expect(backend().opened.last.link.toString(), 'https://a.example/0.m3u8');

      pip.action(PipAction.playPause);
      await tester.pump();
      expect(backend().calls.last, 'playOrPause');

      backend().emit(playing: true);
      pip.action(PipAction.dismissed);
      await tester.pump();
      expect(backend().calls.last, 'pause');
    });

    testAppWidgets('desktop: button enters; only the video and compact controls show; Escape returns', (tester) async {
      await openPlayer(tester);
      await tester.tap(find.byKey(const Key('pipButton')));
      await tester.pumpAndSettle();
      expect(pip.calls.last, 'enter');
      expect(find.byType(DesktopControls), findsNothing);
      expect(find.byType(DesktopControls, skipOffstage: false), findsOneWidget, reason: 'state is kept');
      expect(find.byType(PipView), findsOneWidget);
      expect(find.byKey(const Key('fakeVideo')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(backend().calls.last, 'playOrPause');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(pip.calls.last, 'exit');
      expect(find.byType(PipView), findsNothing);
      expect(find.byType(DesktopControls), findsOneWidget);
      expect(find.byKey(const Key('playerSurface')), findsOneWidget, reason: 'still in the player');
    });

    testAppWidgets('desktop: the keyboard map works again right after returning from PiP', (tester) async {
      await openPlayer(tester);
      await tester.tap(find.byKey(const Key('pipButton')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      final before = backend().calls.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        backend().calls.skip(before),
        contains('playOrPause'),
        reason: 'focus returns to the player, so shortcuts work without moving focus first',
      );
    });

    testAppWidgets('desktop: compact window close stops playback and closes the app', (tester) async {
      await openPlayer(tester);
      await tester.tap(find.byKey(const Key('pipButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pipSurface')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CompactPlayerControls.closeKey));
      // The app closes here; no settling: the emptied player page keeps a spinner running.
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(backend().disposed, isTrue);
      expect(pip.calls.last, 'closeApp');
    });

    testAppWidgets('entering closes open side sheets', (tester) async {
      await openPlayer(tester);
      await tester.tap(find.byKey(const Key('settingsButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-speed')), findsOneWidget);

      await pip.enter();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-speed')), findsNothing);
      expect(find.byType(PipView), findsOneWidget);
    });

    testAppWidgets('phone: button in the top bar; PiP shows the video only, without input', (tester) async {
      await openPlayer(tester, deviceClass: DeviceClass.phone);
      final topBar = find.ancestor(of: find.byKey(const Key('lockButton')), matching: find.byType(Row)).first;
      expect(find.descendant(of: topBar, matching: find.byKey(const Key('pipButton'))), findsOneWidget);

      await tester.tap(find.byKey(const Key('pipButton')));
      await tester.pumpAndSettle();
      expect(find.byType(MobileControls), findsNothing);
      expect(find.byKey(const Key('pipSurface')), findsNothing);
      expect(find.byKey(CompactPlayerControls.closeKey), findsNothing);
    });

    testAppWidgets('no PiP button where unsupported', (tester) async {
      await openPlayer(tester, supported: false);
      expect(find.byKey(const Key('pipButton')), findsNothing);
    });
  });
}
