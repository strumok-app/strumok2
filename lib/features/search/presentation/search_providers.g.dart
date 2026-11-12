// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persisted filters (spec-09 keys `selected_content_language|type|suppliers`).

@ProviderFor(SearchFiltersNotifier)
final searchFiltersProvider = SearchFiltersNotifierProvider._();

/// Persisted filters (spec-09 keys `selected_content_language|type|suppliers`).
final class SearchFiltersNotifierProvider extends $NotifierProvider<SearchFiltersNotifier, SearchFilters> {
  /// Persisted filters (spec-09 keys `selected_content_language|type|suppliers`).
  SearchFiltersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchFiltersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchFiltersNotifierHash();

  @$internal
  @override
  SearchFiltersNotifier create() => SearchFiltersNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchFilters value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<SearchFilters>(value));
  }
}

String _$searchFiltersNotifierHash() => r'f1a026a59bab61e3febab96ad2bb8c39363548ec';

/// Persisted filters (spec-09 keys `selected_content_language|type|suppliers`).

abstract class _$SearchFiltersNotifier extends $Notifier<SearchFilters> {
  SearchFilters build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SearchFilters, SearchFilters>;
    final element =
        ref.element
            as $ClassProviderElement<AnyNotifier<SearchFilters, SearchFilters>, SearchFilters, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SearchHistory)
final searchHistoryProvider = SearchHistoryProvider._();

final class SearchHistoryProvider extends $NotifierProvider<SearchHistory, List<SearchHistoryEntry>> {
  SearchHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchHistoryHash();

  @$internal
  @override
  SearchHistory create() => SearchHistory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SearchHistoryEntry> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<List<SearchHistoryEntry>>(value));
  }
}

String _$searchHistoryHash() => r'6d4965d7d96403e3507cd97d4703509deb371bc9';

abstract class _$SearchHistory extends $Notifier<List<SearchHistoryEntry>> {
  List<SearchHistoryEntry> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<SearchHistoryEntry>, List<SearchHistoryEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<SearchHistoryEntry>, List<SearchHistoryEntry>>,
              List<SearchHistoryEntry>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The submitted query; kept while the app runs so results survive tab switches.

@ProviderFor(SearchQuery)
final searchQueryProvider = SearchQueryProvider._();

/// The submitted query; kept while the app runs so results survive tab switches.
final class SearchQueryProvider extends $NotifierProvider<SearchQuery, String?> {
  /// The submitted query; kept while the app runs so results survive tab switches.
  SearchQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchQueryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchQueryHash();

  @$internal
  @override
  SearchQuery create() => SearchQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<String?>(value));
  }
}

String _$searchQueryHash() => r'81a625aff2260020b36c5a954f3661b2a92ffb67';

/// The submitted query; kept while the app runs so results survive tab switches.

abstract class _$SearchQuery extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<String?, String?>, String?, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(searchSupplierNames)
final searchSupplierNamesProvider = SearchSupplierNamesProvider._();

final class SearchSupplierNamesProvider extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  SearchSupplierNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchSupplierNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchSupplierNamesHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return searchSupplierNames(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<List<String>>(value));
  }
}

String _$searchSupplierNamesHash() => r'371c166c2283477c3dc806ea181b93fb260bc3c4';

/// One supplier's results for a query; suppliers load in parallel, each paginates independently.

@ProviderFor(SearchItems)
final searchItemsProvider = SearchItemsFamily._();

/// One supplier's results for a query; suppliers load in parallel, each paginates independently.
final class SearchItemsProvider extends $NotifierProvider<SearchItems, PagedItems<ContentInfo>> {
  /// One supplier's results for a query; suppliers load in parallel, each paginates independently.
  SearchItemsProvider._({required SearchItemsFamily super.from, required (String, String) super.argument})
    : super(
        retry: null,
        name: r'searchItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchItemsHash();

  @override
  String toString() {
    return r'searchItemsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SearchItems create() => SearchItems();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PagedItems<ContentInfo> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<PagedItems<ContentInfo>>(value));
  }

  @override
  bool operator ==(Object other) {
    return other is SearchItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchItemsHash() => r'a92386641df920412bb150e93dfffdffb031435c';

/// One supplier's results for a query; suppliers load in parallel, each paginates independently.

final class SearchItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          SearchItems,
          PagedItems<ContentInfo>,
          PagedItems<ContentInfo>,
          PagedItems<ContentInfo>,
          (String, String)
        > {
  SearchItemsFamily._()
    : super(
        retry: null,
        name: r'searchItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One supplier's results for a query; suppliers load in parallel, each paginates independently.

  SearchItemsProvider call(String supplier, String query) =>
      SearchItemsProvider._(argument: (supplier, query), from: this);

  @override
  String toString() => r'searchItemsProvider';
}

/// One supplier's results for a query; suppliers load in parallel, each paginates independently.

abstract class _$SearchItems extends $Notifier<PagedItems<ContentInfo>> {
  late final _$args = ref.$arg as (String, String);
  String get supplier => _$args.$1;
  String get query => _$args.$2;

  PagedItems<ContentInfo> build(String supplier, String query);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PagedItems<ContentInfo>, PagedItems<ContentInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PagedItems<ContentInfo>, PagedItems<ContentInfo>>,
              PagedItems<ContentInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

/// True once every searched supplier finished its first page with no results.

@ProviderFor(searchNothingFound)
final searchNothingFoundProvider = SearchNothingFoundProvider._();

/// True once every searched supplier finished its first page with no results.

final class SearchNothingFoundProvider extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  /// True once every searched supplier finished its first page with no results.
  SearchNothingFoundProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchNothingFoundProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchNothingFoundHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return searchNothingFound(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$searchNothingFoundHash() => r'57de2076d8ad2b1cc8d2bf6b1632e6d403ec392a';
