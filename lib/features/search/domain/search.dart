import 'package:content_suppliers_api/content_suppliers_api.dart';

import '../../suppliers/domain/supplier_config.dart';

final class SearchFilters {
  final Set<ContentLanguage> languages;
  final Set<ContentType> types;

  /// Explicitly selected suppliers; empty means all.
  final Set<String> suppliers;

  const SearchFilters({required this.languages, required this.types, this.suppliers = const {}});

  SearchFilters copyWith({Set<ContentLanguage>? languages, Set<ContentType>? types, Set<String>? suppliers}) =>
      SearchFilters(
        languages: languages ?? this.languages,
        types: types ?? this.types,
        suppliers: suppliers ?? this.suppliers,
      );
}

/// Enabled suppliers matching the filters, in user order (spec-01 Search).
List<SupplierConfig> searchableSuppliers(List<SupplierConfig> configs, SearchFilters filters) => [
  for (final config in configs)
    if (config.enabled &&
        (filters.suppliers.isEmpty || filters.suppliers.contains(config.name)) &&
        config.supplier.supportedLanguages.any(filters.languages.contains) &&
        config.supplier.supportedTypes.any(filters.types.contains))
      config,
];

/// Toggles [name]; an empty selection means all, so the first toggle selects only [name].
Set<String> toggleSupplierSelection(Set<String> selected, String name, Iterable<String> all) {
  if (selected.isEmpty) return {name};
  final current = {...selected};
  current.contains(name) ? current.remove(name) : current.add(name);
  return current.length == all.length && current.containsAll(all) ? const {} : current;
}

final class SearchHistoryEntry {
  final String query;
  final DateTime at;

  const SearchHistoryEntry(this.query, this.at);

  factory SearchHistoryEntry.fromJson(Map<String, Object?> json) =>
      SearchHistoryEntry(json['q'] as String, DateTime.fromMillisecondsSinceEpoch(json['t'] as int));

  Map<String, Object?> toJson() => {'q': query, 't': at.millisecondsSinceEpoch};
}

const searchHistoryMaxAge = Duration(days: 30);
const searchHistoryMaxEntries = 50;

/// Newest first, without entries older than [searchHistoryMaxAge].
List<SearchHistoryEntry> pruneSearchHistory(Iterable<SearchHistoryEntry> entries, DateTime now) => [
  for (final e in entries)
    if (now.difference(e.at) <= searchHistoryMaxAge) e,
].take(searchHistoryMaxEntries).toList();

List<SearchHistoryEntry> addToSearchHistory(List<SearchHistoryEntry> entries, String query, DateTime now) =>
    pruneSearchHistory([SearchHistoryEntry(query, now), ...entries.where((e) => e.query != query)], now);

/// History queries containing [input] (case-insensitive), excluding [input] itself.
List<String> searchSuggestions(List<SearchHistoryEntry> entries, String input, {int limit = 8}) {
  final needle = input.trim().toLowerCase();
  return entries
      .map((e) => e.query)
      .where((q) => q.toLowerCase() != needle && q.toLowerCase().contains(needle))
      .take(limit)
      .toList();
}
