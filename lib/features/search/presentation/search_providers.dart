import 'dart:convert';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/paging/paged_items.dart';
import '../../../core/riverpod/cache_for.dart';
import '../../../core/storage/app_preferences.dart';
import '../../suppliers/data/supplier_registry.dart';
import '../../suppliers/presentation/supplier_configs.dart';
import '../domain/search.dart';

part 'search_providers.g.dart';

final _log = Logger('Search');

/// Persisted filters (spec-09 keys `selected_content_language|type|suppliers`).
@Riverpod(keepAlive: true)
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  AppPreferences get _prefs => ref.read(appPreferencesProvider);

  @override
  SearchFilters build() {
    final prefs = ref.read(appPreferencesProvider);
    final uiLanguage = ContentLanguage.values.asNameMap()[ref.read(appLocaleProvider).languageCode];
    Set<T> load<T extends Enum>(String key, List<T> values, Set<T> fallback) {
      final saved = prefs.getStringList(key);
      if (saved == null) return fallback;
      final byName = values.asNameMap();
      return saved.map((n) => byName[n]).nonNulls.toSet();
    }

    return SearchFilters(
      languages: load(AppPreferences.selectedContentLanguage, ContentLanguage.values, {?uiLanguage}),
      types: load(AppPreferences.selectedContentType, ContentType.values, ContentType.values.toSet()),
      suppliers: prefs.getStringList(AppPreferences.selectedContentSuppliers)?.toSet() ?? const {},
    );
  }

  Future<void> toggleLanguage(ContentLanguage language) async {
    final languages = {...state.languages};
    languages.contains(language) ? languages.remove(language) : languages.add(language);
    state = state.copyWith(languages: languages);
    await _prefs.setStringList(AppPreferences.selectedContentLanguage, [for (final l in languages) l.name]);
  }

  Future<void> toggleType(ContentType type) async {
    final types = {...state.types};
    types.contains(type) ? types.remove(type) : types.add(type);
    state = state.copyWith(types: types);
    await _prefs.setStringList(AppPreferences.selectedContentType, [for (final t in types) t.name]);
  }

  Future<void> toggleSupplier(String name) async {
    final all = [
      for (final c in ref.read(supplierConfigsProvider))
        if (c.enabled) c.name,
    ];
    final suppliers = toggleSupplierSelection(state.suppliers, name, all);
    state = state.copyWith(suppliers: suppliers);
    await _prefs.setStringList(AppPreferences.selectedContentSuppliers, suppliers.toList());
  }
}

@Riverpod(keepAlive: true)
class SearchHistory extends _$SearchHistory {
  @override
  List<SearchHistoryEntry> build() {
    final raw = ref.read(appPreferencesProvider).getString(AppPreferences.searchHistory);
    if (raw == null) return const [];
    try {
      final entries = [
        for (final e in jsonDecode(raw) as List) SearchHistoryEntry.fromJson((e as Map).cast<String, Object?>()),
      ];
      return pruneSearchHistory(entries, ref.read(clockProvider)());
    } catch (e) {
      _log.warning('Invalid search history', e);
      return const [];
    }
  }

  Future<void> add(String query) => _save(addToSearchHistory(state, query, ref.read(clockProvider)()));

  Future<void> remove(String query) => _save([
    for (final e in state)
      if (e.query != query) e,
  ]);

  Future<void> _save(List<SearchHistoryEntry> entries) async {
    state = entries;
    await ref
        .read(appPreferencesProvider)
        .setString(AppPreferences.searchHistory, jsonEncode([for (final e in entries) e.toJson()]));
  }
}

/// The submitted query; kept while the app runs so results survive tab switches.
@Riverpod(keepAlive: true)
class SearchQuery extends _$SearchQuery {
  @override
  String? build() => null;

  void submit(String input) {
    final query = input.trim();
    if (query.isEmpty) return;
    state = query;
    ref.read(searchHistoryProvider.notifier).add(query);
  }
}

@Riverpod(keepAlive: true)
List<String> searchSupplierNames(Ref ref) => [
  for (final c in searchableSuppliers(ref.watch(supplierConfigsProvider), ref.watch(searchFiltersProvider))) c.name,
];

/// One supplier's results for a query; suppliers load in parallel, each paginates independently.
@riverpod
class SearchItems extends _$SearchItems {
  @override
  PagedItems<ContentInfo> build(String supplier, String query) {
    ref.cacheFor(const Duration(minutes: 5));
    ref.watch(suppliersProvider);
    Future.microtask(loadMore);
    return const PagedItems();
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final current = state.startLoading();
    state = current;
    final next = await fetchNextPage(current, (page) async {
      final source = ref.read(supplierByNameProvider(supplier));
      return source.search(query, page: page);
    });
    if (ref.mounted) state = next;
  }

  Future<void> retry() async {
    state = state.withoutError();
    await loadMore();
  }
}

/// True once every searched supplier finished its first page with no results.
@riverpod
bool searchNothingFound(Ref ref) {
  final query = ref.watch(searchQueryProvider);
  final suppliers = ref.watch(searchSupplierNamesProvider);
  if (query == null || suppliers.isEmpty) return false;
  final rows = [for (final s in suppliers) ref.watch(searchItemsProvider(s, query))];
  return rows.every((row) => row.isEmptyResult);
}
