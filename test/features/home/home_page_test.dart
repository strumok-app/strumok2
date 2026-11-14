import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/app/widgets/content_card.dart';
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
}
