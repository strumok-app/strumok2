import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/content_card.dart';
import 'package:strumok/app/widgets/content_row.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/home/presentation/home_providers.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

SupplierBundleReady bundleWith(List<FakeSupplier> suppliers) =>
    SupplierBundleReady(FakeBundle(suppliers), bundleInfo('4.0.0'));

void main() {
  testAppWidgets('rows for enabled suppliers and their selected channels', (tester) async {
    final a = FakeSupplier(
      'alpha',
      channels: const {'new', 'top'},
      defaultChannels: const {'new', 'top'},
      onLoadChannel: pagesOf('alpha', pages: 1),
    );
    final en = FakeSupplier('english', supportedLanguages: const {}, onLoadChannel: pagesOf('english'));
    final container = await pumpApp(tester, bundle: bundleWith([a, en]));

    expect(container.read(homeRowsProvider), [
      (supplier: 'alpha', channel: 'new'),
      (supplier: 'alpha', channel: 'top'),
    ]);
    expect(find.text('new  alpha', findRichText: true), findsOneWidget);
    expect(find.text('top  alpha', findRichText: true), findsOneWidget);
    expect(find.byType(ContentCard), findsNWidgets(6));
    expect(en.calls, isEmpty, reason: 'suppliers without the UI language are disabled by default');
  });

  testAppWidgets('arrows on a page pushed over Home never reach the covered Home cards', (tester) async {
    final a = FakeSupplier('alpha', onLoadChannel: pagesOf('alpha', pages: 1));
    final container = await pumpApp(tester, deviceClass: DeviceClass.tv, bundle: bundleWith([a]));
    expect(find.byType(ContentCard), findsWidgets);

    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();

    bool inHome() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<ContentCard>() != null;
    for (final key in [
      for (var i = 0; i < 8; i++) LogicalKeyboardKey.arrowDown,
      for (var i = 0; i < 4; i++) LogicalKeyboardKey.arrowLeft,
      for (var i = 0; i < 8; i++) LogicalKeyboardKey.arrowRight,
      for (var i = 0; i < 12; i++) LogicalKeyboardKey.arrowUp,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(inHome(), isFalse, reason: 'focus moved into the covered Home page with $key');
    }

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(inHome(), isTrue, reason: 'Home is traversable again once it is on top');
  });

  testAppWidgets('empty state links to supplier settings', (tester) async {
    final container = await pumpApp(tester, bundle: bundleWith([FakeSupplier('x', defaultChannels: const {})]));

    expect(find.textContaining('канали рекомендацій'), findsOneWidget);
    await tester.tap(find.text('Налаштувати'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.settingsSuppliers);
  });

  testAppWidgets('touch/mouse: next page loads when the row end is reached', (tester) async {
    final a = FakeSupplier(
      'alpha',
      channels: const {'new'},
      defaultChannels: const {'new'},
      onLoadChannel: pagesOf('alpha', pages: 3, count: 20),
    );
    await pumpApp(tester, bundle: bundleWith([a]));

    expect(a.calls, ['channel:new:1'], reason: 'the first page fills the row');
    await tester.drag(find.byType(ListView).last, const Offset(-3000, 0));
    await tester.pumpAndSettle();
    expect(a.calls, contains('channel:new:2'));
  });

  testAppWidgets('tv: first card focused, explicit focusable load-more tile', (tester) async {
    final a = FakeSupplier(
      'alpha',
      channels: const {'new'},
      defaultChannels: const {'new'},
      onLoadChannel: pagesOf('alpha', pages: 2, count: 2),
    );
    await pumpApp(tester, bundle: bundleWith([a]), deviceClass: DeviceClass.tv);

    expect(a.calls, ['channel:new:1'], reason: 'no automatic paging on TV');
    final firstCard = find.byType(ContentCard).first;
    expect(
      Focus.of(tester.element(find.descendant(of: firstCard, matching: find.byType(AspectRatio)))).hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(a.calls, ['channel:new:1', 'channel:new:2']);
    expect(find.byType(ContentCard), findsNWidgets(4));
  });

  testAppWidgets('card opens details', (tester) async {
    final a = FakeSupplier(
      'alpha',
      channels: const {'new'},
      defaultChannels: const {'new'},
      onLoadChannel: pagesOf('alpha', pages: 1, count: 1),
    );
    final container = await pumpApp(tester, bundle: bundleWith([a]));

    await tester.tap(find.byType(ContentCard).first);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.details('alpha', 'new-1-0'));
  });

  FocusNode? primary() => FocusManager.instance.primaryFocus;
  T? focusedIn<T extends Widget>() => primary()?.context?.findAncestorWidgetOfExactType<T>();

  testAppWidgets('reload loads the row from page 1 again and drops a page requested before it', (tester) async {
    final page2 = Completer<List<ContentInfo>>();
    var reloaded = false;
    final a = FakeSupplier(
      'alpha',
      channels: const {'new'},
      defaultChannels: const {'new'},
      onLoadChannel: (key, page) => page == 2
          ? page2.future
          : Future.value([for (var i = 0; i < 20; i++) FakeInfo('alpha', '$key-$page-$i${reloaded ? '-r' : ''}')]),
    );
    final container = await pumpApp(tester, bundle: bundleWith([a]));
    final notifier = container.read(channelItemsProvider('alpha', 'new').notifier);

    unawaited(notifier.loadMore());
    await tester.pump();
    reloaded = true;
    await tester.tap(find.byKey(const Key('rowReload')));
    await tester.pumpAndSettle();
    page2.complete([const FakeInfo('alpha', 'stale')]);
    await tester.pumpAndSettle();

    expect(a.calls, ['channel:new:1', 'channel:new:2', 'channel:new:1']);
    final ids = container.read(channelItemsProvider('alpha', 'new')).items.map((i) => i.id);
    expect(ids, hasLength(20));
    expect(ids, everyElement(endsWith('-r')));
  });

  testAppWidgets('pick random loads a few more pages, "Another one" changes the pick, "Open" opens details', (
    tester,
  ) async {
    final a = FakeSupplier(
      'alpha',
      channels: const {'new'},
      defaultChannels: const {'new'},
      onLoadChannel: pagesOf('alpha', pages: 10, count: 20),
    );
    final container = await pumpApp(tester, bundle: bundleWith([a]));

    await tester.tap(find.byKey(const Key('rowPickRandom')));
    await tester.pumpAndSettle();
    expect(a.calls, ['channel:new:1', 'channel:new:2', 'channel:new:3'], reason: 'stops at 60 items');

    String pickedTitle() => tester
        .widgetList<Text>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)))
        .map((t) => t.data)
        .firstWhere((t) => t != null && t.startsWith('Title '))!;
    final first = pickedTitle();
    await tester.tap(find.byKey(const Key('randomPickAnother')));
    await tester.pump();
    final second = pickedTitle();
    expect(second, isNot(first));

    await tester.tap(find.byKey(const Key('randomPickOpen')));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.details('alpha', second.substring(6)));
  });

  testAppWidgets('tv: ↑ from cards reaches the row actions, ↓ returns, ↑ again continues to the row above', (
    tester,
  ) async {
    final a = FakeSupplier(
      'alpha',
      channels: const {'new', 'top'},
      defaultChannels: const {'new', 'top'},
      onLoadChannel: pagesOf('alpha', pages: 1, count: 5),
    );
    final container = await pumpApp(tester, deviceClass: DeviceClass.tv, bundle: bundleWith([a]));
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    String? row() => focusedIn<ContentRow>()?.title;

    await press(LogicalKeyboardKey.arrowDown);
    await press(LogicalKeyboardKey.arrowRight);
    expect(focusedIn<ContentCard>()?.info.id, 'top-1-1');

    await press(LogicalKeyboardKey.arrowUp);
    expect((focusedIn<IconButton>()?.key, row()), (const Key('rowPickRandom'), 'top'));
    await press(LogicalKeyboardKey.arrowRight);
    expect((focusedIn<IconButton>()?.key, row()), (const Key('rowReload'), 'top'));
    await press(LogicalKeyboardKey.arrowDown);
    expect(focusedIn<ContentCard>()?.info.id, 'top-1-1', reason: 'back to the last focused card');

    await press(LogicalKeyboardKey.arrowUp);
    await press(LogicalKeyboardKey.arrowUp);
    expect(focusedIn<ContentCard>()?.info.id, startsWith('new-1-'), reason: 'above the row, not its header end');

    await press(LogicalKeyboardKey.arrowUp);
    expect((focusedIn<IconButton>()?.key, row()), (const Key('rowPickRandom'), 'new'));
    await press(LogicalKeyboardKey.select);
    expect(focusedIn<FilledButton>()?.key, const Key('randomPickOpen'), reason: 'result focused on open');
    await press(LogicalKeyboardKey.select);
    expect(container.read(routerProvider).state.uri.path, startsWith('/content/alpha/new-1-'));
  });
}
