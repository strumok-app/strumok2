import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast_io.dart';

import '../../../core/platform/app_paths.dart';
import '../../../core/storage/app_preferences.dart';
import '../../profiles/presentation/profiles_providers.dart';
import '../domain/collection_item.dart';
import '../domain/collection_query.dart';

part 'collection_repository.g.dart';

/// A stored item changed; [item] is null when it was removed.
typedef CollectionChange = ({String key, CollectionItem? item});

/// Collection storage for one profile (spec-03). The Firebase-synced implementation arrives with M4.
abstract interface class CollectionRepository {
  Stream<CollectionChange> get changes;

  Future<List<CollectionItem>> all();

  /// Sets `lastSeen = now`; `status == none` deletes instead (spec-03 §3.3).
  Future<void> save(CollectionItem item);

  Future<void> delete(String key);

  Future<void> close();
}

/// sembast store `collection`: key = item key, value = item JSON + local-only `tokens` (spec-03 §3.5).
class LocalCollectionRepository implements CollectionRepository {
  final DateTime Function() clock;
  final _store = stringMapStoreFactory.store('collection');

  /// Synchronous so the notifier state is current as soon as `save`/`delete` complete.
  final _changes = StreamController<CollectionChange>.broadcast(sync: true);
  final Future<Database> _db;

  LocalCollectionRepository(DatabaseFactory factory, String path, {required this.clock})
    : _db = factory.openDatabase(path);

  @override
  Stream<CollectionChange> get changes => _changes.stream;

  @override
  Future<List<CollectionItem>> all() async {
    final records = await _store.find(await _db);
    return [for (final r in records) CollectionItem.fromJson(r.value)];
  }

  @override
  Future<void> save(CollectionItem item) async {
    if (item.status == CollectionStatus.none) return delete(item.key);
    final saved = item.copyWith(lastSeen: clock().millisecondsSinceEpoch);
    await _store.record(saved.key).put(await _db, {...saved.toJson(), 'tokens': searchTokens(saved.title)});
    _changes.add((key: saved.key, item: saved));
  }

  @override
  Future<void> delete(String key) async {
    await _store.record(key).delete(await _db);
    _changes.add((key: key, item: null));
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await (await _db).close();
  }
}

/// Overridden in tests with an in-memory factory.
@Riverpod(keepAlive: true)
DatabaseFactory collectionDatabaseFactory(Ref ref) => databaseFactoryIo;

/// Re-created when the active profile changes (spec-05 §5.3).
@Riverpod(keepAlive: true)
CollectionRepository collectionRepository(Ref ref) {
  final dir = profileDirectory(ref.watch(appPathsProvider), ref.watch(activeProfileIdProvider));
  final repository = LocalCollectionRepository(
    ref.watch(collectionDatabaseFactoryProvider),
    p.join(dir.path, 'collection.db'),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(repository.close);
  return repository;
}
