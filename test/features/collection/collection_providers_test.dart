import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/data/collection_repository.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/profiles/presentation/profiles_providers.dart';
import 'package:strumok/features/search/presentation/search_providers.dart';

import '../../helpers/test_overrides.dart';

void main() {
  test('repository: save sets lastSeen, keeps local tokens out of the item, none deletes', () async {
    final factory = newDatabaseFactoryMemory();
    final repo = LocalCollectionRepository(factory, 'c.db', clock: () => DateTime.fromMillisecondsSinceEpoch(5000));
    addTearDown(repo.close);
    final changes = <CollectionChange>[];
    repo.changes.listen(changes.add);

    const item = CollectionItem(
      id: 'a/b',
      supplier: 's',
      title: 'Тіні забутих',
      image: '',
      status: CollectionStatus.latter,
    );
    await repo.save(item);
    final stored = (await repo.all()).single;
    expect(stored.lastSeen, 5000);
    expect(stored.toJson().containsKey('tokens'), isFalse);

    final db = await factory.openDatabase('c.db');
    final raw = await stringMapStoreFactory.store('collection').record('sa|b').get(db);
    expect(raw?['tokens'], ['тіні', 'забутих'], reason: 'tokens are local-only');

    await repo.save(stored.copyWith(status: CollectionStatus.none));
    expect(await repo.all(), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(changes.map((c) => c.item?.status), [CollectionStatus.latter, null]);
  });

  test('details status/priority flow and per-profile isolation', () async {
    final c = ProviderContainer(overrides: await testOverrides());
    addTearDown(c.dispose);
    final details = FakeDetails('alpha', 'id/1', title: 'Fresh title');
    await c.read(collectionItemsProvider.future);

    await c.read(collectionItemsProvider.notifier).setStatus(details, CollectionStatus.latter);
    await c
        .read(collectionItemsProvider.notifier)
        .setPriority(collectionItemKey('alpha', 'id/1'), CollectionPriority.high);
    var item = c.read(collectionItemProvider('alpha', 'id/1'))!;
    expect((item.title, item.status, item.priority), ('Fresh title', CollectionStatus.latter, CollectionPriority.high));
    expect(c.read(continueWatchingProvider).single.id, 'id/1');

    final other = await c.read(profilesProvider.notifier).create('Kid', 0xFF000000);
    final firstId = c.read(activeProfileIdProvider);
    await c.read(activeProfileProvider.notifier).select(other.id);
    expect(await c.read(collectionItemsProvider.future), isEmpty);

    await c.read(activeProfileProvider.notifier).select(firstId);
    item = (await c.read(collectionItemsProvider.future)).values.single;
    expect(item.mediaType, MediaType.video);
  });

  test('profiles: default created and persisted, delete rules, search history per profile', () async {
    final prefs = await createTestPreferences();
    final c = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    addTearDown(c.dispose);

    final main = c.read(activeProfileProvider);
    expect(main.name, 'Основний');
    expect(c.read(profilePickPendingProvider), isFalse);

    c.read(searchQueryProvider.notifier).submit('for main');
    final kid = await c.read(profilesProvider.notifier).create('Kid', 0xFF000000);

    await c.read(profilesProvider.notifier).delete(main.id);
    expect(c.read(profilesProvider), hasLength(2), reason: 'active profile cannot be deleted');

    await c.read(activeProfileProvider.notifier).select(kid.id);
    expect(c.read(searchHistoryProvider), isEmpty);
    await c.read(activeProfileProvider.notifier).select(main.id);
    expect(c.read(searchHistoryProvider).single.query, 'for main');

    await c.read(profilesProvider.notifier).delete(kid.id);
    expect(c.read(profilesProvider).map((p) => p.id), [main.id]);
    expect(prefs.getString(AppPreferences.profileSearchHistory(kid.id)), isNull);

    final restarted = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    addTearDown(restarted.dispose);
    expect(restarted.read(activeProfileProvider).id, main.id);
  });

  test('picker is pending at startup with two profiles unless disabled', () async {
    final prefs = await createTestPreferences();
    final first = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    await first.read(profilesProvider.notifier).create('Second', 0xFF000000);
    first.dispose();

    final second = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    addTearDown(second.dispose);
    expect(second.read(profilePickPendingProvider), isTrue);
    await second.read(profileAskOnStartupProvider.notifier).set(false);

    final third = ProviderContainer(overrides: await testOverrides(prefs: prefs));
    addTearDown(third.dispose);
    expect(third.read(profilePickPendingProvider), isFalse);
  });
}
