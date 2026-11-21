import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/core/platform/app_platform.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/suppliers/data/supplier_bundle_installer.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';
import 'package:strumok/features/updates/domain/update_check.dart';
import 'package:strumok/features/updates/presentation/update_providers.dart';

import '../../helpers/test_overrides.dart';

void main() {
  late Directory dir;
  late List<String> loaded;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('strumok_ffi');
    loaded = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> container({
    required http.Client client,
    BundleLoader? loader,
    SupplierBundleState? initial,
  }) async {
    final installer = SupplierBundleInstaller(
      client: client,
      directory: dir,
      platform: AppPlatform.linux,
      downloadKey: 'linux',
      loader:
          loader ??
          (directory, libName) async {
            loaded.add(libName);
            return FakeBundle([FakeSupplier('new_$libName')]);
          },
    );
    final c = ProviderContainer(
      overrides: [
        ...await testOverrides(bundle: initial),
        supplierBundleInstallerProvider.overrideWithValue(installer),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  final okClient = MockClient((_) async => http.Response.bytes(List.filled(1000, 1), 200));

  test('success: downloads, loads, swaps, persists and removes older versions', () async {
    File('${dir.path}/libstrumok_suppliers_5.0.0.so').writeAsStringSync('old');
    File('${dir.path}/libother_1.0.0.so').writeAsStringSync('keep');
    final c = await container(client: okClient);
    final states = <InstallState>[];
    c.listen(supplierBundleInstallControllerProvider, (_, s) => states.add(s));

    final ok = await c.read(supplierBundleInstallControllerProvider.notifier).install(bundleInfo('5.1.0'));

    expect(ok, isTrue);
    expect(loaded, ['strumok_suppliers_5.1.0']);
    expect(c.read(suppliersProvider).single.name, 'new_strumok_suppliers_5.1.0');
    expect(c.read(appPreferencesProvider).getJson(AppPreferences.ffiSupplierBundleInfo)?['version'], '5.1.0');
    expect(File('${dir.path}/libstrumok_suppliers_5.1.0.so').existsSync(), isTrue);
    expect(File('${dir.path}/libstrumok_suppliers_5.0.0.so').existsSync(), isFalse);
    expect(File('${dir.path}/libother_1.0.0.so').existsSync(), isTrue);
    expect(states.whereType<InstallInProgress>(), isNotEmpty);
    expect(states.last, isA<InstallIdle>());
  });

  test('download failure keeps the active bundle', () async {
    final c = await container(client: MockClient((_) async => http.Response('', 500)));

    final ok = await c.read(supplierBundleInstallControllerProvider.notifier).install(bundleInfo('5.1.0'));

    expect(ok, isFalse);
    expect(c.read(supplierBundleInstallControllerProvider), isA<InstallFailed>());
    expect(c.read(supplierRegistryProvider), same(defaultTestBundle));
    expect(dir.listSync(), isEmpty);
  });

  test('load failure deletes the new file and keeps the active bundle', () async {
    final c = await container(
      client: okClient,
      loader: (_, _) async => throw const ContentSuppliersException('bad lib'),
    );

    final ok = await c.read(supplierBundleInstallControllerProvider.notifier).install(bundleInfo('5.1.0'));

    expect(ok, isFalse);
    expect(c.read(supplierBundleInstallControllerProvider), isA<InstallFailed>());
    expect(c.read(supplierRegistryProvider), same(defaultTestBundle));
    expect(File('${dir.path}/libstrumok_suppliers_5.1.0.so').existsSync(), isFalse);
    expect(c.read(appPreferencesProvider).getJson(AppPreferences.ffiSupplierBundleInfo), isNull);
  });

  test('incompatible major is never downloaded', () async {
    var requests = 0;
    final c = await container(
      client: MockClient((_) async {
        requests++;
        return http.Response('', 200);
      }),
    );

    final ok = await c.read(supplierBundleInstallControllerProvider.notifier).install(bundleInfo('6.0.0'));

    expect(ok, isFalse);
    final state = c.read(supplierBundleInstallControllerProvider) as InstallFailed;
    expect(state.error, isA<IncompatibleBundleException>());
    expect(requests, 0);
  });

  test('first install from missing state activates the bundle', () async {
    final c = await container(client: okClient, initial: const SupplierBundleMissing());
    expect(c.read(suppliersProvider), isEmpty);

    await c.read(supplierBundleInstallControllerProvider.notifier).install(bundleInfo('5.1.0'));

    expect(c.read(supplierRegistryProvider), isA<SupplierBundleReady>());
    expect(c.read(suppliersProvider), hasLength(1));
  });
}
