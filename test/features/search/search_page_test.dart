import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/content_card.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  Future<void> openSearch(WidgetTester tester, List<FakeSupplier> suppliers) async {
    final container = await pumpApp(tester, bundle: SupplierBundleReady(FakeBundle(suppliers), bundleInfo('4.0.0')));
    container.read(routerProvider).go(AppRoutes.search);
    await tester.pumpAndSettle();
  }

  testAppWidgets('submitting shows a row per supplier with results; empty suppliers are hidden', (tester) async {
    await openSearch(tester, [
      FakeSupplier('alpha', onSearch: pagesOf('alpha', pages: 1, count: 2)),
      FakeSupplier('beta'),
    ]);
    expect(find.text('Введіть назву для пошуку'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('alpha', findRichText: true), findsOneWidget);
    expect(find.text('beta', findRichText: true), findsNothing);
    expect(find.byType(ContentCard), findsNWidgets(2));
  });

  testAppWidgets('nothing found', (tester) async {
    await openSearch(tester, [FakeSupplier('alpha'), FakeSupplier('beta')]);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Нічого не знайдено'), findsOneWidget);
  });

  testAppWidgets('history suggestions appear while typing and can be reused', (tester) async {
    final alpha = FakeSupplier('alpha', onSearch: pagesOf('alpha', pages: 1, count: 1));
    await openSearch(tester, [alpha]);

    await tester.enterText(find.byType(TextField), 'One Piece');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'one');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'One Piece'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'One Piece'));
    await tester.pumpAndSettle();
    expect(alpha.calls.where((c) => c == 'search:One Piece:1'), hasLength(1), reason: 'cached results reused');
  });

  testAppWidgets('arrow down moves from the field to recent searches, up returns', (tester) async {
    final alpha = FakeSupplier('alpha', onSearch: pagesOf('alpha', pages: 1, count: 1));
    await openSearch(tester, [alpha]);
    for (final q in ['Naruto', 'Bleach']) {
      await tester.enterText(find.byType(TextField), q);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    final first = find.widgetWithText(ListTile, 'Bleach');
    expect(first, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(first, findsOneWidget, reason: 'suggestions stay while focus is in them');
    expect(Focus.of(tester.element(find.descendant(of: first, matching: find.text('Bleach')))).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Naruto');
  });

  testAppWidgets('filters dialog excludes suppliers', (tester) async {
    await openSearch(tester, [
      FakeSupplier('alpha', onSearch: pagesOf('alpha', pages: 1, count: 1)),
      FakeSupplier('beta', onSearch: pagesOf('beta', pages: 1, count: 1)),
    ]);
    await tester.tap(find.byKey(const Key('searchFiltersButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'beta'));
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'x');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('alpha', findRichText: true), findsOneWidget);
    expect(find.text('beta', findRichText: true), findsNothing);
  });
}
