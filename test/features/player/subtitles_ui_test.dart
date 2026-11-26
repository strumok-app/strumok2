import 'dart:async';
import 'dart:convert';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/side_sheet.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/player/data/video_backend.dart';
import 'package:strumok/features/player/domain/equalizer.dart';
import 'package:strumok/features/player/domain/player_preferences.dart';
import 'package:strumok/features/player/domain/player_session.dart';
import 'package:strumok/features/player/presentation/player_controller.dart';
import 'package:strumok/features/player/presentation/player_settings.dart';
import 'package:strumok/features/player/presentation/subtitle_size.dart';
import 'package:strumok/features/player/presentation/widgets/subtitle_overlay.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('merged line backgrounds', () {
    const round = Radius.circular(SubtitleLines.radius);

    test('corners are square where they meet a wider or about as wide neighbor', () {
      final widths = [100.0, 200.0, 195.0, 120.0];
      expect(SubtitleLines.cornersFor(widths, 0), const BorderRadius.vertical(top: round));
      expect(
        SubtitleLines.cornersFor(widths, 1),
        const BorderRadius.vertical(top: round),
        reason: 'sticks out above; the next line is narrower by less than 2 radii',
      );
      expect(SubtitleLines.cornersFor(widths, 2), const BorderRadius.vertical(bottom: round));
      expect(SubtitleLines.cornersFor(widths, 3), const BorderRadius.vertical(bottom: round));
      expect(SubtitleLines.cornersFor([80], 0), const BorderRadius.all(round));
    });

    testWidgets('lines touch without a gap; a shorter line squares the corners facing the longer one', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SubtitleLines(lines: ['Short', 'A much longer second line', 'Mid'], style: TextStyle(fontSize: 20)),
          ),
        ),
      );
      final boxes = find.byType(DecoratedBox);
      final rects = [for (var i = 0; i < 3; i++) tester.getRect(boxes.at(i))];
      expect(rects[0].bottom, rects[1].top);
      expect(rects[1].bottom, rects[2].top);
      expect(rects[0].width, lessThan(rects[1].width));
      BorderRadius corners(int i) =>
          (tester.widget<DecoratedBox>(boxes.at(i)).decoration as BoxDecoration).borderRadius! as BorderRadius;
      expect(corners(0), const BorderRadius.vertical(top: round));
      expect(corners(1), const BorderRadius.all(round));
      expect(corners(2), const BorderRadius.vertical(bottom: round));
    });
  });
  late FakeVideoBackend backend;

  final defaultClient = MockClient(
    (request) async => http.Response.bytes(utf8.encode('1\n00:00:10,000 --> 00:00:20,000\n<i>Привіт</i>\n'), 200),
  );

  Future<ProviderContainer> openPlayer(
    WidgetTester tester, {
    DeviceClass deviceClass = DeviceClass.desktop,
    bool subtitles = true,
    int extraSubtitles = 0,
    PlaybackTracks? tracks,
    http.Client? client,
  }) async {
    final items = [
      FakeMediaItem(
        0,
        'Episode 1',
        sourceList: [
          FakeVideoSource('A'),
          if (subtitles) ...[FakeSubtitleSource('UA', language: ContentLanguage.uk), FakeSubtitleSource('EN')],
          for (var i = 0; i < extraSubtitles; i++) FakeSubtitleSource('Extra $i'),
        ],
      ),
    ];
    final details = FakeDetails('alpha', 'm1', title: 'Movie', loadItems: () async => items);
    final container = await pumpApp(
      tester,
      size: const Size(1280, 720),
      deviceClass: deviceClass,
      client: client ?? defaultClient,
      bundle: SupplierBundleReady(
        FakeBundle([
          FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () {
        backend = FakeVideoBackend();
        if (tracks != null) backend.tracks.value = tracks;
        return backend;
      },
    );
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1')));
    await tester.pumpAndSettle();
    backend.emit(position: const Duration(seconds: 1), duration: const Duration(minutes: 20));
    await tester.pump();
    return container;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  /// Nearest keyed ancestor of the focused node, e.g. a panel row.
  Key? focusedKey() {
    Key? key;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
      key = element.widget.key is ValueKey<String> ? element.widget.key : null;
      return key == null;
    });
    return key;
  }

  const audio = PlaybackTracks(
    audio: [
      MediaTrack('1', language: 'uk'),
      MediaTrack('2', title: 'Original'),
    ],
  );
  const video = PlaybackTracks(
    video: [MediaTrack('1', height: 480), MediaTrack('2', height: 1080), MediaTrack('3', height: 720)],
  );

  Future<void> openSettingsPage(WidgetTester tester, String page) async {
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('settings-$page')));
    await tester.pumpAndSettle();
  }

  testAppWidgets('no subtitles: no show/hide button and no subtitles row; the gear is always there', (tester) async {
    await openPlayer(tester, subtitles: false);
    expect(find.byKey(const Key('subtitlesButton')), findsNothing);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-subtitles')), findsNothing);
    expect(find.byKey(const ValueKey('settings-audio')), findsNothing, reason: 'a single audio track');
  });

  testAppWidgets('show/hide: the button and C turn subtitles on (the last chosen) and off', (tester) async {
    final container = await openPlayer(tester);
    expect(find.byTooltip('Показати субтитри (C)'), findsOneWidget);
    expect(find.byIcon(Icons.closed_caption_off_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('subtitlesButton')));
    await tester.pumpAndSettle();
    expect(container.read(playerControllerProvider)!.subtitle!.description, 'UA', reason: 'nothing chosen yet: first');
    expect(find.byTooltip('Сховати субтитри (C)'), findsOneWidget);
    backend.emit(position: const Duration(seconds: 12));
    await tester.pump();
    final line = find.descendant(of: find.byKey(const Key('subtitleText')), matching: find.byType(Text));
    expect(tester.widget<Text>(line).data, 'Привіт');
    final box = tester.widget<DecoratedBox>(find.ancestor(of: line, matching: find.byType(DecoratedBox)).first);
    expect((box.decoration as BoxDecoration).color, const Color(0x99000000), reason: 'translucent box per line');

    await press(tester, LogicalKeyboardKey.keyC);
    expect(container.read(playerControllerProvider)!.subtitleIndex, isNull);
    expect(find.byKey(const Key('subtitleText')), findsNothing);

    await openSettingsPage(tester, 'subtitles');
    await tester.tap(find.byKey(const ValueKey('subtitle-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyC);
    await press(tester, LogicalKeyboardKey.keyC);
    expect(container.read(playerControllerProvider)!.subtitle!.description, 'EN', reason: 'the last chosen');
  });

  testAppWidgets('settings: Subtitles row and page; choosing stays on the page for size and offset', (tester) async {
    await openPlayer(tester);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-subtitles'));
    expect(find.descendant(of: row, matching: find.text('Вимкнено')), findsOneWidget);
    expect(focusedKey(), const ValueKey('settings-subtitles'), reason: 'first row');

    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text('UA (Українська)'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(focusedKey(), const ValueKey('subtitle-off'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitleSize')), findsOneWidget, reason: 'still on the page');

    await press(tester, LogicalKeyboardKey.escape);
    expect(find.descendant(of: row, matching: find.text('UA (Українська)')), findsOneWidget);
  });

  testAppWidgets('a placeholder shows while the selected subtitles load', (tester) async {
    final response = Completer<http.Response>();
    await openPlayer(tester, client: MockClient((_) => response.future));
    await openSettingsPage(tester, 'subtitles');
    await tester.tap(find.byKey(const ValueKey('subtitle-0')));
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(of: find.byKey(const ValueKey('subtitle-0')), matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(find.text('Завантаження субтитрів…'), findsOneWidget);

    response.complete(http.Response.bytes(utf8.encode('1\n00:00:10,000 --> 00:00:20,000\nA\n'), 200));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('subtitleLoading')), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testAppWidgets('size and offset steppers', (tester) async {
    final container = await openPlayer(tester);
    await openSettingsPage(tester, 'subtitles');
    await tester.tap(find.byKey(const ValueKey('subtitle-0')));
    await tester.pumpAndSettle();

    final size = find.byKey(const ValueKey('subtitleSize'));
    await tester.tap(find.descendant(of: size, matching: find.byTooltip('Збільшити')));
    await tester.pumpAndSettle();
    expect(container.read(subtitleSizeProvider), SubtitleSize.defaultSize + SubtitleSize.step);

    final offset = find.byKey(const ValueKey('subtitleOffset'));
    expect(find.descendant(of: offset, matching: find.text('+0.0 с')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.descendant(of: offset, matching: find.byTooltip('Зменшити')));
      await tester.pumpAndSettle();
    }
    expect(find.descendant(of: offset, matching: find.text('−1.5 с')), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    backend.emit(position: const Duration(seconds: 9));
    await tester.pump();
    expect(find.byKey(const Key('subtitleText')), findsOneWidget, reason: 'shown 1.5 s earlier');
    expect(
      tester
          .widget<Text>(find.descendant(of: find.byKey(const Key('subtitleText')), matching: find.byType(Text)))
          .style!
          .fontSize,
      36,
    );
  });

  testAppWidgets('settings: Audio row with several tracks; picking one switches and returns to the root', (
    tester,
  ) async {
    await openPlayer(tester, subtitles: false, tracks: audio);
    await openSettingsPage(tester, 'audio');
    expect(find.text('uk'), findsOneWidget);
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'audio:2');
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-audio')), matching: find.text('Original')),
      findsOneWidget,
    );
  });

  testAppWidgets('size and offset stay visible under a long subtitles list', (tester) async {
    await openPlayer(tester, extraSubtitles: 30);
    await openSettingsPage(tester, 'subtitles');
    final sheet = tester.getRect(find.byType(SideSheet));
    for (final key in ['subtitleSize', 'subtitleOffset']) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.bottom, lessThanOrEqualTo(sheet.bottom), reason: '$key is on screen');
    }
    expect(find.byKey(const ValueKey('subtitle-31')), findsNothing, reason: 'the list scrolls on its own');
    final clips = find.ancestor(
      of: find.byKey(const ValueKey('subtitle-off')),
      matching: find.byWidgetPredicate((w) => w is Material && w.clipBehavior == Clip.hardEdge),
    );
    expect(clips, findsWidgets, reason: 'selected tile ink must not paint over the header when scrolled');
  });

  testAppWidgets('equalizer drag applies audio effects only when released', (tester) async {
    final container = await openPlayer(tester, subtitles: false);
    await openSettingsPage(tester, 'equalizer');
    final effectCalls = backend.calls.where((call) => call == 'effects').length;
    final band = find.byKey(const ValueKey('equalizer-band-0'));
    final gesture = await tester.startGesture(tester.getCenter(band));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pumpAndSettle();

    expect(container.read(playerSettingsProvider).equalizer, EqualizerGains.flat);
    expect(backend.calls.where((call) => call == 'effects'), hasLength(effectCalls));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(playerSettingsProvider).equalizer, isNot(EqualizerGains.flat));
    expect(backend.calls.where((call) => call == 'effects'), hasLength(effectCalls + 1));
  });

  testAppWidgets('settings: side sheet; a row opens its page, Back returns to the row, picking returns too', (
    tester,
  ) async {
    await openPlayer(tester, subtitles: false, tracks: video);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SideSheet), findsOneWidget);
    expect(find.text('Авто'), findsOneWidget, reason: 'current quality on the root row');
    expect(focusedKey(), const ValueKey('settings-quality'));

    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byKey(const ValueKey('settings-back')), findsOneWidget);
    expect(focusedKey(), const ValueKey('quality-auto'), reason: 'focus on the current choice');
    final labels = ['1080p', '720p', '480p'].map((l) => tester.getTopLeft(find.text(l)).dy).toList();
    expect(labels, orderedEquals([...labels]..sort()));

    await press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(SideSheet), findsOneWidget, reason: 'Back leaves the page, not the sheet');
    expect(focusedKey(), const ValueKey('settings-quality'));

    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('720p'));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'video:3');
    expect(find.byKey(const ValueKey('settings-quality')), findsOneWidget, reason: 'back on the root');
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-quality')), matching: find.text('720p')),
      findsOneWidget,
    );

    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(SideSheet), findsNothing, reason: 'the close button closes from a page too');
  });

  testAppWidgets('settings backdrop closes the side sheet from the root and a submenu', (tester) async {
    await openPlayer(tester, subtitles: false, tracks: video);

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 360));
    await tester.pumpAndSettle();
    expect(find.byType(SideSheet), findsNothing, reason: 'backdrop closes from the root');

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-quality')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-back')), findsOneWidget);

    await tester.tapAt(const Offset(10, 360));
    await tester.pumpAndSettle();
    expect(find.byType(SideSheet), findsNothing, reason: 'backdrop closes the whole sheet from a submenu');
  });

  testAppWidgets('settings: speed, equalizer, start from, on end and shuffle', (tester) async {
    await openPlayer(tester, subtitles: false);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-quality')), findsNothing, reason: 'a single quality has no row');
    Finder row(String page) => find.byKey(ValueKey('settings-$page'));

    await tester.tap(row('speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'speed:1.5');
    expect(find.descendant(of: row('speed'), matching: find.text('1.5×')), findsOneWidget);

    await tester.tap(row('equalizer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('equalizer-cinema')));
    await tester.tap(find.byKey(const ValueKey('equalizer-cinema')));
    await tester.pumpAndSettle();
    expect(backend.audioEffects, AudioEffects(equalizer: EqualizerPreset.cinema.gains));
    final bass = find.byKey(const ValueKey('equalizer-band-0'));
    expect(find.descendant(of: bass, matching: find.text('60')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('equalizer-band-4')), matching: find.text('1к')),
      findsOneWidget,
    );
    await tester.tap(bass);
    await tester.pump(kDoubleTapTimeout);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(find.descendant(of: find.byKey(const ValueKey('equalizer-value')), matching: find.text('+5 дБ')), findsOne);
    await tester.drag(find.byKey(const ValueKey('equalizer-preamp')), const Offset(0, 300));
    await tester.pumpAndSettle();
    final custom = EqualizerPreset.cinema.gains.withBand(0, 5).withPreamp(-20);
    expect(backend.audioEffects, AudioEffects(equalizer: custom), reason: 'the drag wins over the page scroll');
    expect(find.byKey(const ValueKey('equalizer-custom')), findsOneWidget);
    final normalization = find.byKey(const ValueKey('equalizer-volume-normalization'));
    final compression = find.byKey(const ValueKey('equalizer-dynamic-compression'));
    await tester.scrollUntilVisible(normalization, 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(normalization);
    await tester.pumpAndSettle();
    expect(backend.audioEffects, AudioEffects(equalizer: custom, volumeNormalization: true));
    await tester.scrollUntilVisible(compression, 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(compression);
    await tester.pumpAndSettle();
    expect(backend.audioEffects, AudioEffects(equalizer: custom, volumeNormalization: true, dynamicCompression: true));
    await tester.tap(compression);
    await tester.tap(normalization);
    await tester.pumpAndSettle();
    expect(backend.audioEffects, AudioEffects(equalizer: custom));
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: row('equalizer'), matching: find.text('Власний')), findsOneWidget);

    await tester.tap(row('startFrom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('startFrom-fromFixedPosition')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fixedPosition')), findsOneWidget, reason: 'stays open for the time');
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();

    await tester.tap(row('endAction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('endAction-playAgain')));
    await tester.pumpAndSettle();
    await tester.tap(row('shuffle'));
    await tester.pumpAndSettle();

    final settings = ProviderScope.containerOf(tester.element(find.byType(SideSheet))).read(playerSettingsProvider);
    expect(settings.startFrom, StartFrom.fromFixedPosition);
    expect(settings.endAction, EndAction.playAgain);
    expect(settings.shuffle, isTrue);
    expect(settings.equalizer, EqualizerPreset.cinema.gains.withBand(0, 5).withPreamp(-20));
  });

  testAppWidgets('mobile: subtitles lift above visible controls; settings open in a side sheet', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await openPlayer(tester, deviceClass: DeviceClass.phone, tracks: video);
    await tester.tap(find.byKey(const Key('subtitlesButton')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    backend.emit(position: const Duration(seconds: 12));
    await tester.pump();
    final raised = tester.getRect(find.byKey(const Key('subtitleText'))).bottom;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final lowered = tester.getRect(find.byKey(const Key('subtitleText'))).bottom;
    expect(lowered, greaterThan(raised), reason: 'controls hid');

    await tester.tapAt(const Offset(640, 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SideSheet), findsOneWidget);
  });

  testAppWidgets('tv: the subtitles pill toggles them; the settings pill opens on the Subtitles row', (tester) async {
    final container = await openPlayer(tester, deviceClass: DeviceClass.tv, tracks: video);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      focused.findAncestorWidgetOfExactType<Tooltip>()?.message,
      'Показати субтитри',
      reason: 'next is disabled with one item, so → from Play lands on subtitles',
    );
    await press(tester, LogicalKeyboardKey.enter);
    expect(container.read(playerControllerProvider)!.subtitleIndex, 0);
    expect(find.text('Сховати субтитри'), findsOneWidget, reason: 'the focused pill shows the new label');

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(
      FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<Tooltip>()?.message,
      'Джерело',
      reason: 'one source still shows the source pill: its panel refreshes the sources',
    );
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.enter);
    expect(focusedKey(), const ValueKey('settings-subtitles'));
  });
}
