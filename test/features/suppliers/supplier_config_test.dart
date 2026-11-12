import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';
import 'package:strumok/features/suppliers/domain/supplier_config.dart';
import 'package:strumok/features/suppliers/presentation/supplier_configs.dart';

import '../../helpers/test_overrides.dart';

void main() {
  final uk = FakeSupplier('uk_sup');
  final en = FakeSupplier('en_sup', supportedLanguages: const {ContentLanguage.en});
  final fresh = FakeSupplier('fresh');

  List<SupplierConfig> resolve({
    List<String> order = const [],
    Map<String, bool> enabled = const {},
    Map<String, List<String>> channels = const {},
  }) => resolveSupplierConfigs(
    available: [uk, en, fresh],
    savedOrder: order,
    savedEnabled: (n) => enabled[n],
    savedChannels: (n) => channels[n],
    uiLanguage: ContentLanguage.uk,
  );

  test('saved order first, missing removed, new appended', () {
    final configs = resolve(order: ['en_sup', 'gone', 'uk_sup']);
    expect(configs.map((c) => c.name), ['en_sup', 'uk_sup', 'fresh']);
  });

  test('enabled defaults to UI language support', () {
    final configs = resolve();
    expect({for (final c in configs) c.name: c.enabled}, {'uk_sup': true, 'en_sup': false, 'fresh': true});
    expect(resolve(enabled: {'en_sup': true}).firstWhere((c) => c.name == 'en_sup').enabled, isTrue);
  });

  test('channels default to supplier defaults; saved ones intersect current', () {
    expect(resolve().first.channels, {'a'});
    expect(
      resolve(
        channels: {
          'uk_sup': ['b', 'removed'],
        },
      ).first.channels,
      {'b'},
    );
  });

  test('notifier persists changes and rebuilds on bundle swap', () async {
    final c = ProviderContainer(
      overrides: [
        ...await testOverrides(bundle: SupplierBundleReady(FakeBundle([uk, en]), bundleInfo('4.0.0'))),
      ],
    );
    addTearDown(c.dispose);
    final notifier = c.read(supplierConfigsProvider.notifier);

    await notifier.move(0, 1);
    await notifier.setEnabled('uk_sup', false);
    await notifier.setChannel('uk_sup', 'c', true);

    final prefs = c.read(appPreferencesProvider);
    expect(prefs.getStringList(AppPreferences.suppliersOrder), ['en_sup', 'uk_sup']);
    expect(prefs.getBool(AppPreferences.supplierEnabled('uk_sup')), isFalse);
    expect(prefs.getStringList(AppPreferences.supplierChannels('uk_sup')), unorderedEquals(['a', 'c']));

    await c.read(supplierRegistryProvider.notifier).activate(FakeBundle([uk, en, fresh]), bundleInfo('4.1.0'));
    expect(c.read(supplierConfigsProvider).map((c) => c.name), ['en_sup', 'uk_sup', 'fresh']);
  });
}
