// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Active profile's collection by item key; kept current from repository change events.

@ProviderFor(CollectionItems)
final collectionItemsProvider = CollectionItemsProvider._();

/// Active profile's collection by item key; kept current from repository change events.
final class CollectionItemsProvider extends $AsyncNotifierProvider<CollectionItems, Map<String, CollectionItem>> {
  /// Active profile's collection by item key; kept current from repository change events.
  CollectionItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionItemsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionItemsHash();

  @$internal
  @override
  CollectionItems create() => CollectionItems();
}

String _$collectionItemsHash() => r'5cafaeff3ae1cae13bf36e7ac7e19d1d12b060e5';

/// Active profile's collection by item key; kept current from repository change events.

abstract class _$CollectionItems extends $AsyncNotifier<Map<String, CollectionItem>> {
  FutureOr<Map<String, CollectionItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Map<String, CollectionItem>>, Map<String, CollectionItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, CollectionItem>>, Map<String, CollectionItem>>,
              AsyncValue<Map<String, CollectionItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(collectionItem)
final collectionItemProvider = CollectionItemFamily._();

final class CollectionItemProvider extends $FunctionalProvider<CollectionItem?, CollectionItem?, CollectionItem?>
    with $Provider<CollectionItem?> {
  CollectionItemProvider._({required CollectionItemFamily super.from, required (String, String) super.argument})
    : super(
        retry: null,
        name: r'collectionItemProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionItemHash();

  @override
  String toString() {
    return r'collectionItemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<CollectionItem?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  CollectionItem? create(Ref ref) {
    final argument = this.argument as (String, String);
    return collectionItem(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionItem? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<CollectionItem?>(value));
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionItemHash() => r'158a44cf7995eb92aa0ff68ef750423c5a7e56d3';

final class CollectionItemFamily extends $Family with $FunctionalFamilyOverride<CollectionItem?, (String, String)> {
  CollectionItemFamily._()
    : super(
        retry: null,
        name: r'collectionItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CollectionItemProvider call(String supplier, String id) =>
      CollectionItemProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'collectionItemProvider';
}

@ProviderFor(CollectionFilterNotifier)
final collectionFilterProvider = CollectionFilterNotifierProvider._();

final class CollectionFilterNotifierProvider extends $NotifierProvider<CollectionFilterNotifier, CollectionFilter> {
  CollectionFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionFilterNotifierHash();

  @$internal
  @override
  CollectionFilterNotifier create() => CollectionFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionFilter value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<CollectionFilter>(value));
  }
}

String _$collectionFilterNotifierHash() => r'651b622150cb7a6d1e28a2fa10d9d5a57841217b';

abstract class _$CollectionFilterNotifier extends $Notifier<CollectionFilter> {
  CollectionFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CollectionFilter, CollectionFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CollectionFilter, CollectionFilter>,
              CollectionFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(collectionGroups)
final collectionGroupsProvider = CollectionGroupsProvider._();

final class CollectionGroupsProvider
    extends
        $FunctionalProvider<
          List<(CollectionStatus, List<CollectionItem>)>,
          List<(CollectionStatus, List<CollectionItem>)>,
          List<(CollectionStatus, List<CollectionItem>)>
        >
    with $Provider<List<(CollectionStatus, List<CollectionItem>)>> {
  CollectionGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionGroupsHash();

  @$internal
  @override
  $ProviderElement<List<(CollectionStatus, List<CollectionItem>)>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<(CollectionStatus, List<CollectionItem>)> create(Ref ref) {
    return collectionGroups(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<(CollectionStatus, List<CollectionItem>)> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<(CollectionStatus, List<CollectionItem>)>>(value),
    );
  }
}

String _$collectionGroupsHash() => r'acc7d3e20dc3176c1413e9c4812db3c2285ee03f';

/// Supplier filter options: present in the collection and installed (spec-01 Collection).

@ProviderFor(collectionSuppliers)
final collectionSuppliersProvider = CollectionSuppliersProvider._();

/// Supplier filter options: present in the collection and installed (spec-01 Collection).

final class CollectionSuppliersProvider extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Supplier filter options: present in the collection and installed (spec-01 Collection).
  CollectionSuppliersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionSuppliersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionSuppliersHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return collectionSuppliers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<List<String>>(value));
  }
}

String _$collectionSuppliersHash() => r'25f937045e6e010b9b792b389bbf8599330beca7';

@ProviderFor(continueWatching)
final continueWatchingProvider = ContinueWatchingProvider._();

final class ContinueWatchingProvider
    extends $FunctionalProvider<List<CollectionItem>, List<CollectionItem>, List<CollectionItem>>
    with $Provider<List<CollectionItem>> {
  ContinueWatchingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueWatchingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueWatchingHash();

  @$internal
  @override
  $ProviderElement<List<CollectionItem>> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  List<CollectionItem> create(Ref ref) {
    return continueWatching(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CollectionItem> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<List<CollectionItem>>(value));
  }
}

String _$continueWatchingHash() => r'e3db2981b2d25cd1c7292e0013449f83d1371391';
