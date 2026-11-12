import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/updates/data/update_repositories.dart';
import 'package:strumok/features/updates/domain/bundle_update_status.dart';
import 'package:strumok/features/updates/presentation/update_providers.dart';

import '../../helpers/test_overrides.dart';

void main() {
  late DateTime now;
  late int requests;
  late http.Response Function() respond;

  setUp(() {
    now = DateTime(2026, 1, 1);
    requests = 0;
    respond = () => http.Response(jsonEncode(bundleInfo('4.1.0').toJson()), 200);
  });

  Future<ProviderContainer> container() async {
    final client = MockClient((_) async {
      requests++;
      return respond();
    });
    final c = ProviderContainer(
      overrides: [
        ...await testOverrides(client: client),
        clockProvider.overrideWithValue(() => now),
        supplierBundleInfoRepositoryProvider.overrideWithValue(
          SupplierBundleInfoRepository(client, 'https://example.com/bundle.json'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('silent checks are throttled to once per 12 h', () async {
    final c = await container();
    final notifier = c.read(latestSupplierBundleProvider.notifier);

    await notifier.check(silent: true);
    expect(requests, 1);
    expect(c.read(supplierBundleUpdateStatusProvider), BundleUpdateStatus.updateAvailable);

    now = now.add(const Duration(hours: 6));
    await notifier.check(silent: true);
    expect(requests, 1);

    await notifier.check();
    expect(requests, 2, reason: 'manual checks are never throttled');

    now = now.add(const Duration(hours: 13));
    await notifier.check(silent: true);
    expect(requests, 3);
  });

  test('silent failures are not shown; manual failures are', () async {
    respond = () => http.Response('', 503);
    final c = await container();
    final notifier = c.read(latestSupplierBundleProvider.notifier);

    await notifier.check(silent: true);
    expect(c.read(latestSupplierBundleProvider).error, isNull);

    await notifier.check();
    expect(c.read(latestSupplierBundleProvider).error, isNotNull);
  });

  test('latest info is cached across restarts', () async {
    final c = await container();
    await c.read(latestSupplierBundleProvider.notifier).check(silent: true);
    final prefs = c.read(appPreferencesProvider);
    expect(prefs.getJson(AppPreferences.ffiUpdateLatestInfo)?['version'], '4.1.0');

    final restarted = ProviderContainer(overrides: [...await testOverrides(prefs: prefs)]);
    addTearDown(restarted.dispose);
    expect(restarted.read(latestSupplierBundleProvider).latest?.versionString, '4.1.0');
  });

  test('app update is available only for a newer version', () async {
    final c = ProviderContainer(overrides: [...await testOverrides(appVersion: '1.31.5')]);
    addTearDown(c.dispose);
    final prefs = c.read(appPreferencesProvider);
    await prefs.setJson(AppPreferences.appUpdateLatestRelease, {'name': 'v1.32.0', 'assets': <Object>[]});

    final restarted = ProviderContainer(
      overrides: [...await testOverrides(prefs: prefs, appVersion: '1.31.5')],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(availableAppUpdateProvider)?.name, 'v1.32.0');
    expect(restarted.read(hasUpdateNoticeProvider), isTrue);

    final current = ProviderContainer(
      overrides: [...await testOverrides(prefs: prefs, appVersion: '1.32.0')],
    );
    addTearDown(current.dispose);
    expect(current.read(availableAppUpdateProvider), isNull);
  });
}
