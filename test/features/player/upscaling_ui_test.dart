import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/localization.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/player/domain/upscaling.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  late FakeVideoBackend backend;
  final anime4k = upscalerById('anime4k_a_fast')!;

  Future<ProviderContainer> openSettings(WidgetTester tester, {List<Upscaler> supported = const []}) async {
    final details = FakeDetails(
      'alpha',
      'm1',
      title: 'Movie',
      loadItems: () async => [
        FakeMediaItem(0, 'Episode 1', sourceList: [FakeVideoSource('A')]),
      ],
    );
    final container = await pumpApp(
      tester,
      size: const Size(1280, 720),
      prefs: await createTestPreferences(),
      bundle: SupplierBundleReady(
        FakeBundle([
          FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () => backend = FakeVideoBackend(supportedUpscalers: supported),
    );
    unawaited(container.read(routerProvider).push(AppRoutes.video('alpha', 'm1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    return container;
  }

  final row = find.byKey(const ValueKey('settings-upscaling'));

  ListTile tileOf(WidgetTester tester, Finder keyed) =>
      tester.widget<ListTile>(find.descendant(of: keyed, matching: find.byType(ListTile), matchRoot: true).first);

  String subtitleOf(WidgetTester tester, Finder keyed) => (tileOf(tester, keyed).subtitle! as Text).data!;

  testAppWidgets('hidden where no upscaler can run (Android, TV, Windows for now)', (tester) async {
    await openSettings(tester);
    expect(find.byKey(const ValueKey('settings-speed')), findsOneWidget);
    expect(row, findsNothing);
  });

  testAppWidgets('player settings sheet has a transparent backdrop', (tester) async {
    await openSettings(tester);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color?.a ?? 0, 0);
  });

  testAppWidgets('flat upscaler choices keep the page open and update when selected', (tester) async {
    final custom = upscalerById('luma_cas_grain')!;
    final container = await openSettings(tester, supported: [anime4k, custom]);
    final l10n = tester.element(row).l10n;
    expect(subtitleOf(tester, row), l10n.playerUpscalingOff);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tileOf(tester, find.byKey(const ValueKey('upscaler-off'))).selected, isTrue);
    expect(find.byKey(const ValueKey('upscaler-luma_cas_grain')), findsOneWidget);
    expect(find.text('LUMA/CAS/FILM GRAIN'), findsOneWidget);
    expect(subtitleOf(tester, find.byKey(const ValueKey('upscaler-anime4k_a_fast'))), l10n.playerUpscalerCostLight);
    expect(find.text(l10n.playerUpscalingDescription), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('upscaler-anime4k_a_fast')));
    await tester.pumpAndSettle();

    expect(backend.upscaler, anime4k);
    expect(container.read(appPreferencesProvider).getString(AppPreferences.videoPlayerUpscaler), 'anime4k_a_fast');
    expect(find.byKey(const ValueKey('settings-back')), findsOneWidget, reason: 'remain on the upscaler page');
    expect(tileOf(tester, find.byKey(const ValueKey('upscaler-anime4k_a_fast'))).selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    expect(subtitleOf(tester, row), l10n.playerUpscalerAnime4kAFast, reason: 'back on the root, showing the new value');
  });

  testAppWidgets('a failing upscaler shows a message once and the setting reads off', (tester) async {
    await openSettings(tester, supported: [anime4k]);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('upscaler-anime4k_a_fast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    final l10n = tester.element(row).l10n;

    backend.failUpscaler();
    await tester.pumpAndSettle();

    final name = l10n.playerUpscalerAnime4kAFast;
    expect(find.text(l10n.playerUpscalingFailed(name)), findsOneWidget);
    expect(subtitleOf(tester, row), l10n.playerUpscalingOff);
  });
}
