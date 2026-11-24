import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/search/presentation/search_providers.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/test_overrides.dart';

void main() {
  Future<ProviderContainer> container(List<FakeSupplier> suppliers) async {
    final c = ProviderContainer(
      overrides: await testOverrides(bundle: SupplierBundleReady(FakeBundle(suppliers), bundleInfo('4.0.0'))),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('suppliers are searched in parallel and paginate independently', () async {
    final slow = Completer<List<ContentInfo>>();
    final a = FakeSupplier('a', onSearch: pagesOf('a', pages: 1));
    final b = FakeSupplier('b', onSearch: (_, _) => slow.future);
    final c = await container([a, b]);

    c.read(searchQueryProvider.notifier).submit('  matrix ');
    final names = c.read(searchSupplierNamesProvider);
    expect(names, ['a', 'b']);
    for (final n in names) {
      c.listen(searchItemsProvider(n, 'matrix'), (_, _) {});
    }
    await settle();

    expect(a.calls, ['search:matrix:1']);
    expect(b.calls, ['search:matrix:1']);
    expect(c.read(searchItemsProvider('a', 'matrix')).items, hasLength(3));
    expect(c.read(searchItemsProvider('b', 'matrix')).loading, isTrue);

    await c.read(searchItemsProvider('a', 'matrix').notifier).loadMore();
    expect(a.calls.last, 'search:matrix:2');
    expect(c.read(searchItemsProvider('a', 'matrix')).hasMore, isFalse);

    slow.complete(const []);
    await settle();
    expect(c.read(searchNothingFoundProvider), isFalse, reason: 'a found items');
  });

  test('nothing found when every supplier returns an empty first page', () async {
    final c = await container([FakeSupplier('a'), FakeSupplier('b')]);
    c.read(searchQueryProvider.notifier).submit('zzz');
    c.listen(searchNothingFoundProvider, (_, _) {});
    await settle();
    expect(c.read(searchNothingFoundProvider), isTrue);
  });

  test('errors are per supplier and retryable', () async {
    var fail = true;
    final a = FakeSupplier('a', onSearch: (q, p) async => fail ? throw StateError('down') : [FakeInfo('a', '1')]);
    final c = await container([a]);
    c.read(searchQueryProvider.notifier).submit('x');
    c.listen(searchItemsProvider('a', 'x'), (_, _) {});
    await settle();
    expect(c.read(searchItemsProvider('a', 'x')).error, isNotNull);

    fail = false;
    await c.read(searchItemsProvider('a', 'x').notifier).retry();
    expect(c.read(searchItemsProvider('a', 'x')).items, hasLength(1));
  });

  test('persisted languages the app no longer supports (e.g. legacy "ja") are ignored', () async {
    final prefs = await createTestPreferences({
      AppPreferences.selectedContentLanguage: ['ja', 'en'],
    });
    final c = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    addTearDown(c.dispose);
    expect(c.read(searchFiltersProvider).languages, {ContentLanguage.en});
  });

  test('filters and history are persisted', () async {
    final c = await container([FakeSupplier('a'), FakeSupplier('b')]);
    expect(c.read(searchFiltersProvider).languages, {ContentLanguage.uk});

    await c.read(searchFiltersProvider.notifier).toggleLanguage(ContentLanguage.en);
    await c.read(searchFiltersProvider.notifier).toggleType(ContentType.manga);
    await c.read(searchFiltersProvider.notifier).toggleSupplier('b');
    c.read(searchQueryProvider.notifier).submit('first');
    c.read(searchQueryProvider.notifier).submit('second');
    await settle();

    final prefs = c.read(appPreferencesProvider);
    expect(prefs.getStringList(AppPreferences.selectedContentLanguage), unorderedEquals(['uk', 'en']));
    expect(prefs.getStringList(AppPreferences.selectedContentType), isNot(contains('manga')));
    expect(prefs.getStringList(AppPreferences.selectedContentSuppliers), ['b']);
    expect(c.read(searchSupplierNamesProvider), ['b']);

    final restarted = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    addTearDown(restarted.dispose);
    expect(restarted.read(searchHistoryProvider).map((e) => e.query), ['second', 'first']);
    expect(restarted.read(searchFiltersProvider).suppliers, {'b'});
  });
}
