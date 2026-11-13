import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../suppliers/data/supplier_registry.dart';
import '../data/collection_repository.dart';
import '../domain/collection_item.dart';
import '../domain/collection_query.dart';
import '../domain/progress.dart';

part 'collection_providers.g.dart';

/// Active profile's collection by item key; kept current from repository change events.
@Riverpod(keepAlive: true)
class CollectionItems extends _$CollectionItems {
  CollectionRepository get _repository => ref.read(collectionRepositoryProvider);

  @override
  Future<Map<String, CollectionItem>> build() async {
    final repository = ref.watch(collectionRepositoryProvider);
    final subscription = repository.changes.listen((change) {
      final current = state.value;
      if (current == null) return;
      final next = {...current}..remove(change.key);
      if (change.item case final item?) next[change.key] = item;
      state = AsyncData(next);
    });
    ref.onDispose(subscription.cancel);
    return {for (final item in await repository.all()) item.key: item};
  }

  /// Adds/updates from details; title and image are refreshed from fresh supplier data (spec-03 §3.3).
  Future<void> setStatus(ContentDetails details, CollectionStatus status) {
    final key = collectionItemKey(details.supplier, details.id);
    final base =
        state.value?[key] ??
        CollectionItem(
          id: details.id,
          supplier: details.supplier,
          title: details.title,
          image: details.image,
          mediaType: details.mediaType,
        );
    return _repository.save(base.copyWith(title: details.title, image: details.image, status: status));
  }

  Future<void> setPriority(String key, CollectionPriority priority) async {
    final item = state.value?[key];
    final updated = item == null ? null : updatePriority(item, priority);
    if (updated != null) await _repository.save(updated);
  }

  Future<void> save(CollectionItem item) => _repository.save(item);
}

@riverpod
CollectionItem? collectionItem(Ref ref, String supplier, String id) {
  final key = collectionItemKey(supplier, id);
  return ref.watch(collectionItemsProvider.select((items) => items.value?[key]));
}

@Riverpod(keepAlive: true)
class CollectionFilterNotifier extends _$CollectionFilterNotifier {
  @override
  CollectionFilter build() => const CollectionFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleStatus(CollectionStatus status) => state = state.copyWith(statuses: _toggle(state.statuses, status));

  void toggleMediaType(MediaType type) => state = state.copyWith(mediaTypes: _toggle(state.mediaTypes, type));

  void toggleSupplier(String supplier) => state = state.copyWith(suppliers: _toggle(state.suppliers, supplier));

  static Set<T> _toggle<T>(Set<T> set, T value) => set.contains(value) ? ({...set}..remove(value)) : {...set, value};
}

@riverpod
List<(CollectionStatus, List<CollectionItem>)> collectionGroups(Ref ref) {
  final items = ref.watch(collectionItemsProvider).value?.values ?? const [];
  return groupCollection(items, ref.watch(collectionFilterProvider));
}

/// Supplier filter options: present in the collection and installed (spec-01 Collection).
@riverpod
List<String> collectionSuppliers(Ref ref) {
  final installed = {for (final s in ref.watch(suppliersProvider)) s.name};
  final present = {...?ref.watch(collectionItemsProvider).value?.values.map((i) => i.supplier)};
  return [
    for (final s in present)
      if (installed.contains(s)) s,
  ]..sort();
}

@riverpod
List<CollectionItem> continueWatching(Ref ref) =>
    continueItems(ref.watch(collectionItemsProvider).value?.values ?? const []);
