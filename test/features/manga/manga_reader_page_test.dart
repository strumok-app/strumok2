import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/side_sheet.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/manga/data/manga_page_images.dart';
import 'package:strumok/features/manga/domain/auto_crop.dart';
import 'package:strumok/features/manga/domain/manga_reader_preferences.dart';
import 'package:strumok/features/manga/domain/manga_reader_state.dart';
import 'package:strumok/features/manga/presentation/manga_reader_controller.dart';
import 'package:strumok/features/manga/presentation/manga_reader_page.dart';
import 'package:strumok/features/manga/presentation/manga_reader_settings.dart';
import 'package:strumok/features/manga/presentation/widgets/long_strip_reader_view.dart';
import 'package:strumok/features/manga/presentation/widgets/paged_reader_view.dart';
import 'package:strumok/features/manga/presentation/widgets/reader_zoom.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_manga.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

/// Pages load [image] at once, or fail for URLs in [failing]; crop detection (real engine work) is skipped.
class FakePageImages extends MangaPageImages {
  final ui.Image image;
  final Set<String> failing;
  final requested = <(String, Map<String, String>?)>[];
  final retried = <String>[];
  final cropped = <(String, bool)>[];

  FakePageImages(this.image, {this.failing = const {}}) : super(FakeCacheManager());

  @override
  ImageProvider provider(String page, {Map<String, String>? headers}) {
    requested.add((page, headers));
    return _TestImage(page, this);
  }

  @override
  Future<CropRect?> crop(String page, ui.Image image, {required bool vertical}) async {
    cropped.add((page, vertical));
    return null;
  }
}

class _TestImage extends ImageProvider<_TestImage> {
  final String page;
  final FakePageImages images;

  _TestImage(this.page, this.images);

  @override
  Future<_TestImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TestImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(
    images.failing.contains(page)
        ? Future.error(Exception('HTTP 500'))
        : SynchronousFuture(ImageInfo(image: images.image.clone())),
  );

  @override
  Future<bool> evict({ImageCache? cache, ImageConfiguration configuration = ImageConfiguration.empty}) async {
    images.retried.add(page);
    return super.evict(cache: cache, configuration: configuration);
  }

  @override
  bool operator ==(Object other) => other is _TestImage && other.page == page && identical(other.images, images);

  @override
  int get hashCode => Object.hash(page, identityHashCode(images));
}

void main() {
  late ui.Image pageImage;
  late ProviderContainer container;
  late FakePageImages images;
  final provider = mangaReaderControllerProvider('alpha', 'm1');

  MangaReaderState reader() => container.read(provider);

  setUpAll(() async => pageImage = await createTestImage(width: 70, height: 100));

  Future<void> openReader(
    WidgetTester tester, {
    MangaReaderMode mode = MangaReaderMode.leftToRight,
    DeviceClass deviceClass = DeviceClass.desktop,
    List<FakeMediaItem>? chapters,
    Set<String> failing = const {},
    int? item,
  }) async {
    images = FakePageImages(pageImage, failing: failing);
    final supplier = FakeSupplier(
      'alpha',
      details: {
        'm1': mangaDetails(chapters ?? [chapter(0), chapter(1)]),
      },
    );
    container = await pumpApp(
      tester,
      deviceClass: deviceClass,
      bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')),
      prefs: await createTestPreferences({AppPreferences.mangaReaderMode: mode.name}),
      extraOverrides: [mangaPageImagesProvider.overrideWithValue(images)],
    );
    unawaited(container.read(routerProvider).push(AppRoutes.manga('alpha', 'm1', item: item)));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  bool controlsVisible(WidgetTester tester) => !tester
      .widget<IgnorePointer>(
        find.ancestor(of: find.byKey(const Key('readerPageCounter')), matching: find.byType(IgnorePointer)).first,
      )
      .ignoring;

  testAppWidgets('paged left-to-right: arrows turn pages and save progress', (tester) async {
    await openReader(tester);
    expect(find.byType(PagedReaderView), findsOneWidget);
    expect(reader().page, 0);
    expect(images.requested.first.$1, pageUrls('UA', 0, 5).first);
    expect(images.requested.first.$2, {'referer': 'https://manga.example'});

    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.space);
    expect(reader().page, 2);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(reader().page, 1);

    final item = container.read(collectionItemsProvider).value![collectionItemKey('alpha', 'm1')]!;
    expect(item.positions[0], const MediaItemPosition(position: 1, length: 5));
    expect(item.status, CollectionStatus.inProgress);
  });

  testAppWidgets('right-to-left: ← reads forward', (tester) async {
    await openReader(tester, mode: MangaReaderMode.rightToLeft);
    expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(reader().page, 1);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(reader().page, 0);
  });

  testAppWidgets('past the last page: the next-chapter page, then the next chapter', (tester) async {
    await openReader(tester);
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.pageDown);
    }
    expect(reader().page, 4);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Кінець: Chapter 1'), findsOneWidget);
    expect(reader().itemIndex, 0);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(reader().itemIndex, 1);
    expect(reader().page, 0);
  });

  testAppWidgets('before the first page: the previous chapter opens at its last page', (tester) async {
    await openReader(tester, item: 1);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('Початок: Chapter 2'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(reader().itemIndex, 0);
    expect(reader().page, 4);
  });

  testAppWidgets('tap zones: sides turn pages, the middle toggles the controls', (tester) async {
    await openReader(tester);
    final size = tester.getSize(find.byType(PagedReaderView));

    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(reader().page, 1);

    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(controlsVisible(tester), isTrue);
    expect(find.text('2 / 5'), findsOneWidget);

    await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(reader().page, 0);
    expect(controlsVisible(tester), isFalse);
  });

  testAppWidgets('zoom: double-tap and ctrl+wheel zoom; a zoomed page pans instead of turning', (tester) async {
    await openReader(tester);
    final center = tester.getCenter(find.byType(PagedReaderView));
    final zoom = tester.state<ReaderZoomState>(find.byType(ReaderZoom));
    PageView pager() => tester.widget<PageView>(find.byType(PageView));

    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(zoom.scale, ReaderZoom.doubleTapScale);
    expect(pager().physics, isA<NeverScrollableScrollPhysics>());
    expect(controlsVisible(tester), isFalse, reason: 'a double tap is not a tap');

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(reader().page, 1);
    expect(zoom.zoomed, isFalse, reason: 'turning the page resets the zoom');

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(zoom.zoomed, isTrue);
    expect(reader().page, 1);

    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(zoom.zoomed, isFalse);
  });

  group('touch gestures', () {
    Future<void> pinch(WidgetTester tester, Offset center, {double spread = 80}) async {
      final a = await tester.startGesture(center - const Offset(0, 40), pointer: 1);
      final b = await tester.startGesture(center + const Offset(0, 40), pointer: 2);
      for (var i = 0; i < 4; i++) {
        await a.moveBy(Offset(0, -spread / 4));
        await b.moveBy(Offset(0, spread / 4));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    double stripOffset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: find.byType(LongStripReaderView), matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;

    testAppWidgets('long strip: a slanted swipe scrolls instead of being taken as a pan', (tester) async {
      await openReader(tester, mode: MangaReaderMode.longStrip, deviceClass: DeviceClass.phone);
      // Small steps like a real finger: 36 px of travel come before 18 px of vertical travel.
      final finger = await tester.startGesture(tester.getCenter(find.byType(LongStripReaderView)));
      for (var i = 0; i < 20; i++) {
        await finger.moveBy(const Offset(-6, -2));
        await tester.pump();
      }
      await finger.up();
      await tester.pumpAndSettle();
      expect(stripOffset(tester), greaterThan(0));
    });

    testAppWidgets('long strip: pinch zooms without scrolling; zoomed, drags scroll and pan', (tester) async {
      await openReader(tester, mode: MangaReaderMode.longStrip, deviceClass: DeviceClass.phone);
      final center = tester.getCenter(find.byType(LongStripReaderView));
      final zoom = tester.state<ReaderZoomState>(find.byType(ReaderZoom));

      await pinch(tester, center);
      expect(zoom.scale, greaterThan(1.5));
      expect(stripOffset(tester), 0, reason: 'the pinch moved fingers vertically but must not scroll');

      final scaled = zoom.scale;
      await tester.dragFrom(center, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(stripOffset(tester), greaterThan(0));
      expect(zoom.scale, scaled);

      final before = zoom.offset;
      await tester.dragFrom(center, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(zoom.offset.dx, greaterThan(before.dx));
    });

    testAppWidgets('paged: pinch zooms without turning the page; zoomed, drags pan', (tester) async {
      await openReader(tester, mode: MangaReaderMode.leftToRight, deviceClass: DeviceClass.phone);
      final center = tester.getCenter(find.byType(PagedReaderView));
      final zoom = tester.state<ReaderZoomState>(find.byType(ReaderZoom));
      final pager = tester.widget<PageView>(find.byType(PageView)).controller!;

      // A horizontal spread: the same direction a swipe would turn the page in.
      final a = await tester.startGesture(center - const Offset(40, 0), pointer: 1);
      final b = await tester.startGesture(center + const Offset(40, 0), pointer: 2);
      for (var i = 0; i < 4; i++) {
        await a.moveBy(const Offset(-30, 0));
        await b.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(zoom.scale, greaterThan(1.2));
      expect(pager.page, 0);

      final before = zoom.offset;
      await tester.dragFrom(center, const Offset(-150, -60));
      await tester.pumpAndSettle();
      expect(zoom.offset.dx, lessThan(before.dx));
      expect(zoom.offset.dy, lessThan(before.dy));
      expect(pager.page, 0, reason: 'zoomed: drags pan instead of turning the page');
      expect(reader().page, 0);
    });
  });

  testAppWidgets('paged: the mouse wheel turns pages', (tester) async {
    await openReader(tester, mode: MangaReaderMode.vertical);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byType(PagedReaderView))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pumpAndSettle();
    expect(reader().page, 1);
  });

  testAppWidgets('paged: wheel events during a page turn do not scroll the pager', (tester) async {
    await openReader(tester, mode: MangaReaderMode.vertical);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byType(PagedReaderView))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    // Mid-animation the pager ignores pointers on its pages; a smooth wheel keeps sending small deltas.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -15)));
    }
    await tester.pumpAndSettle();
    expect(pager.page, 1);
    expect(reader().page, 1);
  });

  testAppWidgets('auto-crop trims all sides when paged, only the sides in a long strip', (tester) async {
    await openReader(tester);
    expect(images.cropped, contains((pageUrls('UA', 0, 5).first, true)));

    await container.read(mangaReaderSettingsProvider.notifier).setMode(MangaReaderMode.longStrip);
    await tester.pumpAndSettle();
    expect(images.cropped, contains((pageUrls('UA', 0, 5).first, false)));
  });

  testAppWidgets('Enter shows the controls on the slider; Esc hides them, then leaves', (tester) async {
    await openReader(tester);
    final router = container.read(routerProvider);

    await press(tester, LogicalKeyboardKey.enter);
    expect(controlsVisible(tester), isTrue);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'readerSlider');

    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(reader().page, 2);
    expect(find.text('3 / 5'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);
    expect(controlsVisible(tester), isFalse);
    expect(router.state.uri.path, '/manga/alpha/m1');

    await press(tester, LogicalKeyboardKey.escape);
    expect(router.state.uri.path, AppRoutes.home);
    expect(find.byType(MangaReaderPage), findsNothing);
  });

  testAppWidgets('TV: D-pad only; no back button in the top bar', (tester) async {
    await openReader(tester, deviceClass: DeviceClass.tv);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(reader().page, 1);

    await press(tester, LogicalKeyboardKey.select);
    expect(controlsVisible(tester), isTrue);
    expect(find.byType(BackButton), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'readerSlider');

    // Up from the slider reaches the top bar actions.
    await press(tester, LogicalKeyboardKey.arrowUp);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<IconButton>(), isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.goBack, platform: 'web', physicalKey: PhysicalKeyboardKey.browserBack);
    await tester.pumpAndSettle();
    expect(controlsVisible(tester), isFalse);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'readerRoot');
  });

  testAppWidgets('long strip: keys scroll, the slider jumps to a page', (tester) async {
    await openReader(tester, mode: MangaReaderMode.longStrip);
    expect(find.byType(LongStripReaderView), findsOneWidget);
    final scrollable = find.descendant(of: find.byType(LongStripReaderView), matching: find.byType(Scrollable)).first;
    double offset() => tester.state<ScrollableState>(scrollable).position.pixels;

    await press(tester, LogicalKeyboardKey.pageDown);
    expect(offset(), greaterThan(0));
    await press(tester, LogicalKeyboardKey.pageUp);
    expect(offset(), 0);

    // Pages are 70×100 at 800 wide (1143 tall); the current page crosses 30% of the screen.
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(reader().page, 0);
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(reader().page, 1);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(reader().page, 0);

    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(reader().page, 3);
    expect(find.text('4 / 5'), findsOneWidget);
  });

  testAppWidgets('settings side sheet switches the mode and persists it', (tester) async {
    await openReader(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(const Key('readerSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SideSheet), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      focused.findAncestorWidgetOfExactType<ListTile>(),
      tester.widget<ListTile>(
        find.descendant(of: find.byKey(const ValueKey('readerMode-leftToRight')), matching: find.byType(ListTile)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('readerMode-longStrip')));
    await tester.tap(find.byKey(const ValueKey('readerBackground-light')));
    await tester.pumpAndSettle();
    expect(container.read(mangaReaderSettingsProvider).mode, MangaReaderMode.longStrip);
    expect(container.read(appPreferencesProvider).getString(AppPreferences.mangaReaderBackground), 'light');

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(LongStripReaderView), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, Colors.white);
  });

  testAppWidgets('translation selector switches the source', (tester) async {
    await openReader(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(const Key('readerTranslationButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('readerSource-1')));
    await tester.pumpAndSettle();
    expect(reader().source!.description, 'EN');
    expect(reader().pages, pageUrls('EN', 0, 4));
  });

  testAppWidgets('chapter list opens the picked chapter', (tester) async {
    await openReader(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.byKey(const Key('readerChaptersButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mediaItem-1')));
    await tester.pumpAndSettle();
    expect(reader().itemIndex, 1);
  });

  testAppWidgets('a failed page offers Retry; OK retries the current page', (tester) async {
    final first = pageUrls('UA', 0, 5).first;
    await openReader(tester, failing: {first});
    expect(find.text('Не вдалося завантажити сторінку 1'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter);
    expect(images.retried, [first]);
    expect(controlsVisible(tester), isFalse);
  });

  testAppWidgets('a chapter that fails to load shows Retry, focused', (tester) async {
    var attempt = 0;
    final source = FakeMangaSource(
      'UA',
      load: () async => ++attempt == 1 ? throw Exception('offline') : pageUrls('UA', 0, 3),
    );
    await openReader(
      tester,
      chapters: [
        chapter(0, sources: [source]),
      ],
    );
    expect(find.text('Не вдалося завантажити розділ'), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<FilledButton>()?.key, const Key('readerRetry'));

    await press(tester, LogicalKeyboardKey.enter);
    expect(reader().ready, isTrue);
    expect(find.byType(PagedReaderView), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'readerRoot');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(reader().page, 1);
  });
}
