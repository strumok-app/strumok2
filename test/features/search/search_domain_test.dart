import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/search/domain/search.dart';
import 'package:strumok/features/suppliers/domain/supplier_config.dart';

import '../../helpers/test_overrides.dart';

void main() {
  SupplierConfig config(FakeSupplier s, {bool enabled = true}) =>
      SupplierConfig(supplier: s, enabled: enabled, channels: const {});

  group('searchableSuppliers', () {
    final uk = config(FakeSupplier('uk', supportedTypes: const {ContentType.movie, ContentType.series}));
    final en = config(FakeSupplier('en', supportedLanguages: const {ContentLanguage.en}));
    final manga = config(FakeSupplier('manga', supportedTypes: const {ContentType.manga}));
    final disabled = config(FakeSupplier('off'), enabled: false);
    final all = [uk, en, manga, disabled];

    test('requires language and type intersections, enabled only', () {
      final filters = SearchFilters(languages: const {ContentLanguage.uk}, types: const {ContentType.series});
      expect(searchableSuppliers(all, filters).map((c) => c.name), ['uk']);
    });

    test('explicit supplier selection; empty means all', () {
      final filters = SearchFilters(languages: ContentLanguage.values.toSet(), types: ContentType.values.toSet());
      expect(searchableSuppliers(all, filters).map((c) => c.name), ['uk', 'en', 'manga']);
      expect(searchableSuppliers(all, filters.copyWith(suppliers: {'en'})).map((c) => c.name), ['en']);
    });
  });

  test('toggling suppliers with "empty = all" semantics', () {
    const all = ['a', 'b', 'c'];
    expect(toggleSupplierSelection(const {}, 'b', all), {'a', 'c'});
    expect(toggleSupplierSelection(const {'a', 'c'}, 'b', all), isEmpty);
    expect(toggleSupplierSelection(const {'a'}, 'a', all), isEmpty);
  });

  group('history', () {
    final now = DateTime(2026, 6, 1);

    test('newest first, deduplicated', () {
      var history = addToSearchHistory(const [], 'one', now);
      history = addToSearchHistory(history, 'two', now.add(const Duration(minutes: 1)));
      history = addToSearchHistory(history, 'one', now.add(const Duration(minutes: 2)));
      expect(history.map((e) => e.query), ['one', 'two']);
    });

    test('drops entries older than 30 days and caps the size', () {
      final old = SearchHistoryEntry('old', now.subtract(const Duration(days: 31)));
      final many = [for (var i = 0; i < 60; i++) SearchHistoryEntry('q$i', now)];
      expect(pruneSearchHistory([...many, old], now), hasLength(searchHistoryMaxEntries));
      expect(pruneSearchHistory([old], now), isEmpty);
    });

    test('suggestions are case-insensitive substring matches without the exact input', () {
      final entries = [
        for (final q in ['Naruto', 'One Piece', 'naruto shippuden']) SearchHistoryEntry(q, now),
      ];
      expect(searchSuggestions(entries, 'NARU'), ['Naruto', 'naruto shippuden']);
      expect(searchSuggestions(entries, 'naruto'), ['naruto shippuden']);
      expect(searchSuggestions(entries, ''), hasLength(3));
    });

    test('json round-trip', () {
      final entry = SearchHistoryEntry('query', now);
      final again = SearchHistoryEntry.fromJson(entry.toJson());
      expect((again.query, again.at), (entry.query, entry.at));
    });
  });
}
