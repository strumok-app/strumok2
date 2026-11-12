import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/features/details/presentation/details_providers.dart';
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
  }) async {
    final supplier = FakeSupplier('alpha', details: {details.id: details});
    final container = await pumpApp(
      tester,
      size: size,
      bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0')),
    );
    unawaited(container.read(routerProvider).push(AppRoutes.details('alpha', details.id)));
    await tester.pumpAndSettle();
    return (container, supplier);
  }

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
    await tester.tap(find.widgetWithText(ListTile, 'Episode 1'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.toString(), '/video/alpha/m1?item=2');
  });

  testAppWidgets('single section has no tabs; escape closes the sheet', (tester) async {
    final oneSeason = [for (var i = 0; i < 3; i++) FakeMediaItem(i, 'Ep $i')];
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => oneSeason));

    await tester.tap(find.byKey(const Key('mediaItemsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.widgetWithText(ListTile, 'Ep 0'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Ep 0'), findsNothing);
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

  testAppWidgets('narrow layout renders', (tester) async {
    await open(tester, FakeDetails('alpha', 'm1', loadItems: () async => items), size: const Size(400, 800));
    expect(find.text('Fake title'), findsOneWidget);
    expect(find.text('Дивитися'), findsOneWidget);
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
  });
}
