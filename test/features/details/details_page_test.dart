import 'dart:async';
import 'dart:ui' as ui;

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/app_network_image.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/details/presentation/details_page.dart';
import 'package:strumok/features/details/presentation/details_providers.dart';
import 'package:strumok/features/details/presentation/poster_header.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  final items = [
    const FakeMediaItem(0, 'Episode 1', section: 'Season 1'),
    const FakeMediaItem(1, 'Episode 2', section: 'Season 1'),
    const FakeMediaItem(2, 'Episode 1', section: 'Season 2'),
  ];

  test('groupBySection keeps supplier order and indexes', () {
    final groups = groupBySection(items);
    expect(groups.map((g) => g.$1), ['Season 1', 'Season 2']);
    expect(groups.first.$2.map((i) => i.number), [0, 1]);
  });

  Future<(dynamic, FakeSupplier)> open(
    WidgetTester tester,
    FakeDetails details, {
    Size size = const Size(1280, 720),
    BaseCacheManager? imageCache,
  }) async {
    final supplier = FakeSupplier('alpha', details: {details.id: details});
    final container = await pumpApp(
      tester,
      size: size,
      imageCache: imageCache,
      bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')),
    );
    unawaited(container.read(routerProvider).push(AppRoutes.details('alpha', details.id)));
    await tester.pumpAndSettle();
    return (container, supplier);
  }

  testAppWidgets('desktop density: episodes icon button is as tall as the action buttons', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => items));

    final button = find.byKey(const Key('mediaItemsButton'));
    final height = tester.getSize(find.widgetWithText(FilledButton, 'Дивитися')).height;
    expect(tester.getSize(button).height, height);
    expect(find.byTooltip('Епізоди'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testAppWidgets('video details: info, autofocused Watch, episodes sheet with season tabs', (tester) async {
    final (container, _) = await open(
      tester,
      FakeDetails('alpha', 'm1', similar: [const FakeInfo('alpha', 's1')], loadItems: () async => items),
    );

    expect(find.text('Fake title'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Схоже'), findsOneWidget);
    expect(find.text('Episode 1'), findsNothing, reason: 'episodes live in the side sheet');

    final watch = find.widgetWithText(FilledButton, 'Дивитися');
    expect(Focus.of(tester.element(find.descendant(of: watch, matching: find.text('Дивитися')))).hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('mediaItemsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Episode 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Season 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Episode 1'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.toString(), '/video/alpha/m1?item=2');
  });

  testAppWidgets('episodes sheet shows previews, collection progress and opens at the current item', (tester) async {
    final withImages = [
      for (final item in items)
        FakeMediaItem(item.number, item.title, section: item.section, image: 'thumb-${item.number}'),
    ];
    final (container, _) = await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => withImages));
    await tester.runAsync(
      () => container
          .read(collectionItemsProvider.notifier)
          .save(
            const CollectionItem(
              id: 'm1',
              supplier: 'alpha',
              title: 'Fake title',
              image: '',
              currentItem: 2,
              status: CollectionStatus.inProgress,
              positions: {
                0: MediaItemPosition(position: 2390, length: 2400),
                1: MediaItemPosition(position: 600, length: 2400),
                2: MediaItemPosition(position: 75),
              },
            ),
          ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mediaItemsButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AppNetworkImage), findsWidgets);
    final current = find.byKey(const ValueKey('mediaItem-2'));
    expect(
      find.descendant(of: current, matching: find.text('Episode 1')),
      findsOneWidget,
      reason: 'opens on Season 2',
    );
    expect(find.descendant(of: current, matching: find.byIcon(Icons.play_arrow)), findsOneWidget);
    expect(Focus.of(tester.element(find.descendant(of: current, matching: find.text('Episode 1')))).hasFocus, isTrue);
    double? progressOf(Finder tile) => tester
        .widget<LinearProgressIndicator>(find.descendant(of: tile, matching: find.byType(LinearProgressIndicator)))
        .value;
    expect(progressOf(current), 0, reason: 'unknown length');

    await tester.tap(find.widgetWithText(Tab, 'Season 1'));
    await tester.pumpAndSettle();
    for (final key in ['mediaItem-0', 'mediaItem-1']) {
      expect(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byIcon(Icons.play_arrow)), findsNothing);
    }
    expect(progressOf(find.byKey(const ValueKey('mediaItem-0'))), 1, reason: 'watched to the end');
    expect(progressOf(find.byKey(const ValueKey('mediaItem-1'))), 0.25);
  });

  testAppWidgets('keys: coming back up to Watch reveals the title above it', (tester) async {
    await open(
      tester,
      FakeDetails('alpha', 'm1', similar: [for (var i = 0; i < 3; i++) FakeInfo('alpha', 's$i')]),
      size: const Size(1280, 420),
    );
    ScrollPosition position() => tester
        .state<ScrollableState>(find.ancestor(of: find.text('Fake title'), matching: find.byType(Scrollable)).first)
        .position;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(position().pixels, greaterThan(0), reason: 'the similar row is below the fold');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
  });

  testAppWidgets('single section has no tabs; escape closes the sheet', (tester) async {
    final oneSeason = [for (var i = 0; i < 3; i++) FakeMediaItem(i, 'Ep $i')];
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => oneSeason));

    await tester.tap(find.byKey(const Key('mediaItemsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Ep 0'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Ep 0'), findsNothing);
    expect(find.text('Fake title'), findsOneWidget);
  });

  testAppWidgets('single item content has no episodes button', (tester) async {
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => [const FakeMediaItem(0, 'Movie')]));
    expect(find.byKey(const Key('mediaItemsButton')), findsNothing);
  });

  testAppWidgets('manga details use Read and open the reader', (tester) async {
    final (container, _) = await open(tester, FakeDetails('alpha', 'k1', mediaType: MediaType.manga));

    expect(find.text('Розділи'), findsNothing, reason: 'empty item list is hidden');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.manga('alpha', 'k1'));
  });

  testAppWidgets('wide layout: poster is flush with the pane edges', (tester) async {
    await open(
      tester,
      FakeDetails('alpha', 'm1', similar: [const FakeInfo('alpha', 's1')], loadItems: () async => items),
    );
    final pane = tester.getRect(find.byType(DetailsPage));
    final poster = tester.getRect(
      find.descendant(of: find.byType(DetailsPage), matching: find.byType(AppNetworkImage)).last,
    );
    expect(poster.topRight, pane.topRight);
    expect(poster.bottom, pane.bottom);

    final similar = find.ancestor(of: find.text('Схоже', findRichText: true), matching: find.byType(ShaderMask));
    expect(similar, findsOneWidget, reason: 'rows fade out at the poster');
    expect(tester.getRect(similar).right, poster.left, reason: 'rows end flush with the poster, never under it');
  });

  testAppWidgets('narrow layout: title and actions over the poster, collection status below', (tester) async {
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => items), size: const Size(400, 800));
    final header = find.byType(PosterHeader);
    final headerRect = tester.getRect(header);
    for (final finder in [find.text('Fake title'), find.text('Original'), find.text('Дивитися')]) {
      expect(find.descendant(of: header, matching: finder), findsOneWidget);
    }
    final episodes = find.byKey(const Key('mediaItemsButton'));
    expect(find.descendant(of: header, matching: episodes), findsOneWidget);
    expect(tester.getRect(episodes).top, lessThan(tester.getRect(find.text('Fake title')).bottom), reason: 'title row');
    expect(tester.getRect(episodes).left, greaterThan(tester.getRect(find.text('Fake title')).right));
    expect(headerRect.bottom - tester.getRect(find.widgetWithText(FilledButton, 'Дивитися')).bottom, 8);

    final collection = find.byKey(const Key('collectionButton'));
    expect(find.descendant(of: header, matching: collection), findsNothing);
    expect(tester.getRect(collection).top, greaterThan(headerRect.bottom));
    expect(find.text('Description'), findsOneWidget);
  });

  testAppWidgets('narrow layout: portrait poster fills the width, capped to keep info visible', (tester) async {
    await open(tester, FakeDetails('alpha', 'm1', image: 'https://img/p.jpg'), size: const Size(400, 1400));
    final pane = tester.getRect(find.byType(DetailsPage));
    final header = tester.getRect(find.byType(PosterHeader));
    expect(header.width, pane.width);
    expect(header.height, moreOrLessEquals(pane.width * 1.5), reason: 'image size unknown yet: 2:3 poster assumed');

    tester.view.physicalSize = const Size(400, 700);
    await tester.pumpAndSettle();
    final capped = tester.getRect(find.byType(PosterHeader)).height;
    expect(capped, moreOrLessEquals(tester.getRect(find.byType(DetailsPage)).height * 0.7));
  });

  testAppWidgets('narrow layout: tapping the poster toggles the title and Watch bars', (tester) async {
    await open(
      tester,
      FakeDetails('alpha', 'm1', image: 'https://img/p.jpg', loadItems: () async => items),
      size: const Size(400, 800),
    );
    final watch = find.widgetWithText(FilledButton, 'Дивитися');
    final title = find.text('Fake title');
    final episodes = find.byKey(const Key('mediaItemsButton'));
    final poster = tester.getCenter(find.byType(PosterHeader));

    await tester.tapAt(poster);
    await tester.pumpAndSettle();
    for (final finder in [watch, title, episodes]) {
      expect(finder.hitTestable(), findsNothing);
    }
    expect(find.byKey(const Key('collectionButton')).hitTestable(), findsOneWidget, reason: 'below the poster');

    await tester.tapAt(poster);
    await tester.pumpAndSettle();
    for (final finder in [watch, title, episodes]) {
      expect(finder.hitTestable(), findsOneWidget);
    }
  });

  group('poster at its own aspect ratio', () {
    /// Opens details whose poster is a generated `width`×`height` PNG and waits until it is decoded.
    Future<void> openWithPoster(WidgetTester tester, int width, int height, {required Size size}) async {
      final url = 'https://img/${width}x$height.png';
      final bytes = (await tester.runAsync(() => _png(width, height)))!;
      await open(
        tester,
        FakeDetails('alpha', 'm1', image: url),
        size: size,
        imageCache: _MemoryImageCache({url: bytes}),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
      }
    }

    Rect posterRect(WidgetTester tester) =>
        tester.getRect(find.descendant(of: find.byType(DetailsPage), matching: find.byType(AppNetworkImage)).last);
    final backdrop = find.byKey(const ValueKey('backdrop'));

    testAppWidgets('wide: portrait poster pane follows the image ratio, nothing cropped or blurred', (tester) async {
      await openWithPoster(tester, 300, 500, size: const Size(1280, 720));
      final pane = tester.getRect(find.byType(DetailsPage));
      expect(posterRect(tester).width, moreOrLessEquals(pane.height * 0.6));
      expect(posterRect(tester).height, pane.height);
      expect(backdrop, findsNothing);
    });

    testAppWidgets('wide: landscape poster is capped and shown whole over a blurred backdrop', (tester) async {
      await openWithPoster(tester, 640, 360, size: const Size(1280, 720));
      final pane = tester.getRect(find.byType(DetailsPage));
      expect(posterRect(tester).width, moreOrLessEquals(pane.width * 0.4));
      expect(posterRect(tester).right, pane.right);
      expect(backdrop, findsOneWidget);
      final poster = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage).last);
      expect(poster.fit, BoxFit.contain);
    });

    testAppWidgets('narrow: landscape poster header is as tall as the image at full width', (tester) async {
      await openWithPoster(tester, 600, 400, size: const Size(400, 800));
      final header = tester.getRect(find.byType(PosterHeader));
      expect(header.height, moreOrLessEquals(header.width * 400 / 600));
    });
  });

  testAppWidgets('narrow layout without poster shrinks the header to its content', (tester) async {
    await open(tester, FakeDetails('alpha', 'm1'), size: const Size(400, 800));
    expect(tester.getRect(find.byType(PosterHeader)).height, lessThan(250));
  });

  testAppWidgets('media items error is retryable in the sheet', (tester) async {
    var fail = true;
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => fail ? throw StateError('x') : items));

    await tester.tap(find.byKey(const Key('mediaItemsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Не вдалося завантажити'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторити'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Season 1'), findsOneWidget);
  });

  testAppWidgets('unknown content shows not found with retry', (tester) async {
    final supplier = FakeSupplier('alpha');
    final container = await pumpApp(tester, bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')));
    unawaited(container.read(routerProvider).push(AppRoutes.details('alpha', 'missing')));
    await tester.pumpAndSettle();
    expect(find.text('Контент не знайдено'), findsOneWidget);
    expect(find.text('Повторити'), findsOneWidget);
    expect(find.text('Видалити з колекції'), findsNothing, reason: 'not in the collection');
  });

  for (final (name, supplierName, message) in [
    ('content not found', 'alpha', 'Контент не знайдено'),
    ('supplier missing', 'gone', 'Постачальник «gone» недоступний'),
  ]) {
    testAppWidgets('$name: collection item can be removed from the error page', (tester) async {
      final container = await pumpApp(
        tester,
        bundle: SupplierBundleReady(FakeBundle([FakeSupplier('alpha')]), bundleInfo('4.0.0')),
      );
      await tester.runAsync(
        () => container
            .read(collectionItemsProvider.notifier)
            .save(
              CollectionItem(
                id: 'x1',
                supplier: supplierName,
                title: 'Old',
                image: '',
                status: CollectionStatus.latter,
              ),
            ),
      );
      final router = container.read(routerProvider);
      unawaited(router.push(AppRoutes.details(supplierName, 'x1')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);

      await tester.tap(find.text('Видалити з колекції'));
      await tester.pumpAndSettle();
      expect(container.read(collectionItemProvider(supplierName, 'x1')), isNull);
      expect(router.state.uri.path, isNot(AppRoutes.details(supplierName, 'x1')));
    });
  }

  testAppWidgets('retry shows loading until details arrive', (tester) async {
    final supplier = _GatedSupplier('alpha', FakeDetails('alpha', 'm1'));
    final container = await pumpApp(tester, bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')));
    unawaited(container.read(routerProvider).push(AppRoutes.details('alpha', 'm1')));
    await tester.pump();
    supplier.gate.completeError(StateError('x'));
    await tester.pumpAndSettle();
    expect(find.text('Повторити'), findsOneWidget);

    supplier.gate = Completer();
    await tester.tap(find.text('Повторити'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Повторити'), findsNothing);

    supplier.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Fake title'), findsOneWidget);
  });
}

class _GatedSupplier extends FakeSupplier {
  final ContentDetails item;
  Completer<void> gate = Completer();

  _GatedSupplier(super.name, this.item);

  @override
  Future<ContentDetails?> detailsById(String id) async {
    await gate.future;
    return item;
  }
}

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xFF8040C0), BlendMode.src);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Serves images from memory by url.
class _MemoryImageCache extends Fake implements BaseCacheManager {
  final Map<String, Uint8List> images;
  final _files = MemoryCacheSystem();

  _MemoryImageCache(this.images);

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final file = await _files.createFile(Uri.parse(url).pathSegments.last);
    await file.writeAsBytes(images[url]!);
    yield FileInfo(file, FileSource.Online, DateTime(2100), url);
  }
}
