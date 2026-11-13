// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Overridden in tests with an in-memory factory.

@ProviderFor(collectionDatabaseFactory)
final collectionDatabaseFactoryProvider = CollectionDatabaseFactoryProvider._();

/// Overridden in tests with an in-memory factory.

final class CollectionDatabaseFactoryProvider
    extends $FunctionalProvider<DatabaseFactory, DatabaseFactory, DatabaseFactory>
    with $Provider<DatabaseFactory> {
  /// Overridden in tests with an in-memory factory.
  CollectionDatabaseFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionDatabaseFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionDatabaseFactoryHash();

  @$internal
  @override
  $ProviderElement<DatabaseFactory> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  DatabaseFactory create(Ref ref) {
    return collectionDatabaseFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DatabaseFactory value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<DatabaseFactory>(value));
  }
}

String _$collectionDatabaseFactoryHash() => r'ca200536ed7a05db5129d2c277aa8c124ef09ec0';

/// Re-created when the active profile changes (spec-05 §5.3).

@ProviderFor(collectionRepository)
final collectionRepositoryProvider = CollectionRepositoryProvider._();

/// Re-created when the active profile changes (spec-05 §5.3).

final class CollectionRepositoryProvider
    extends $FunctionalProvider<CollectionRepository, CollectionRepository, CollectionRepository>
    with $Provider<CollectionRepository> {
  /// Re-created when the active profile changes (spec-05 §5.3).
  CollectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<CollectionRepository> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  CollectionRepository create(Ref ref) {
    return collectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionRepository value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<CollectionRepository>(value));
  }
}

String _$collectionRepositoryHash() => r'83a056df0ba1253395087030d0d4b2cb01c2f7c7';
