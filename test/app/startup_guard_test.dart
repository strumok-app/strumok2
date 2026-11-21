import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/app_platform.dart';
import 'package:strumok/features/suppliers/data/supplier_bundle_installer.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';
import 'package:strumok/features/updates/data/update_repositories.dart';

import '../helpers/test_app.dart';
import '../helpers/test_overrides.dart';

void main() {
  testAppWidgets('missing bundle shows install prompt; installing reveals the shell without restart', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('.json')) return http.Response(jsonEncode(bundleInfo('5.2.0').toJson()), 200);
      return http.Response.bytes(List.filled(100, 0), 200);
    });
    final dir = await tester.runAsync(() async => Directory.systemTemp.createTemp('strumok_guard'));

    final container = await pumpApp(
      tester,
      bundle: const SupplierBundleMissing(),
      extraOverrides: [
        supplierBundleInfoRepositoryProvider.overrideWithValue(
          SupplierBundleInfoRepository(client, 'https://example.com/bundle.json'),
        ),
        supplierBundleInstallerProvider.overrideWithValue(
          SupplierBundleInstaller(
            client: client,
            directory: dir!,
            platform: AppPlatform.linux,
            downloadKey: 'linux',
            loader: (_, _) async => FakeBundle([FakeSupplier('dummy')]),
          ),
        ),
      ],
    );
    final router = container.read(routerProvider);

    expect(router.state.uri.path, AppRoutes.install);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Остання версія: 5.2.0'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Встановити'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(container.read(supplierRegistryProvider), isA<SupplierBundleReady>());
    expect(router.state.uri.path, AppRoutes.home);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testAppWidgets('ready bundle never shows the install prompt', (tester) async {
    final container = await pumpApp(tester);
    expect(container.read(routerProvider).state.uri.path, AppRoutes.home);
  });
}
