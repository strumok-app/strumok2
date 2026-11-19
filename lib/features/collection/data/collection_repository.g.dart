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
    extends
        $FunctionalProvider<DatabaseFactory, DatabaseFactory, DatabaseFactory>
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
  $ProviderElement<DatabaseFactory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DatabaseFactory create(Ref ref) {
    return collectionDatabaseFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DatabaseFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DatabaseFactory>(value),
    );
  }
}

String _$collectionDatabaseFactoryHash() =>
    r'ca200536ed7a05db5129d2c277aa8c124ef09ec0';

/// The active profile's local store; re-created when the active profile changes (spec-05 §5.3).

@ProviderFor(localCollectionRepository)
final localCollectionRepositoryProvider = LocalCollectionRepositoryProvider._();

/// The active profile's local store; re-created when the active profile changes (spec-05 §5.3).

final class LocalCollectionRepositoryProvider
    extends
        $FunctionalProvider<
          LocalCollectionRepository,
          LocalCollectionRepository,
          LocalCollectionRepository
        >
    with $Provider<LocalCollectionRepository> {
  /// The active profile's local store; re-created when the active profile changes (spec-05 §5.3).
  LocalCollectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localCollectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localCollectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<LocalCollectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalCollectionRepository create(Ref ref) {
    return localCollectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalCollectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalCollectionRepository>(value),
    );
  }
}

String _$localCollectionRepositoryHash() =>
    r'ba6bbefb6e131048ace1452c16417411c08aaa7c';

/// Opens `/collection/{uid}` in the profile's Firebase app; overridden in tests.

@ProviderFor(remoteCollectionConnector)
final remoteCollectionConnectorProvider = RemoteCollectionConnectorProvider._();

/// Opens `/collection/{uid}` in the profile's Firebase app; overridden in tests.

final class RemoteCollectionConnectorProvider
    extends
        $FunctionalProvider<
          RemoteCollectionConnector,
          RemoteCollectionConnector,
          RemoteCollectionConnector
        >
    with $Provider<RemoteCollectionConnector> {
  /// Opens `/collection/{uid}` in the profile's Firebase app; overridden in tests.
  RemoteCollectionConnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteCollectionConnectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteCollectionConnectorHash();

  @$internal
  @override
  $ProviderElement<RemoteCollectionConnector> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteCollectionConnector create(Ref ref) {
    return remoteCollectionConnector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteCollectionConnector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteCollectionConnector>(value),
    );
  }
}

String _$remoteCollectionConnectorHash() =>
    r'426683fd3b95c10f1f48f6da62c083e116f8aff4';

/// Account the active collection syncs with: none in offline mode or when signed out (spec-03 §3.6).

@ProviderFor(collectionSyncUid)
final collectionSyncUidProvider = CollectionSyncUidProvider._();

/// Account the active collection syncs with: none in offline mode or when signed out (spec-03 §3.6).

final class CollectionSyncUidProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Account the active collection syncs with: none in offline mode or when signed out (spec-03 §3.6).
  CollectionSyncUidProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionSyncUidProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionSyncUidHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return collectionSyncUid(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$collectionSyncUidHash() => r'47907d0aeaefe99d42922eb753a0b72855a9e0d8';

/// Local-only, or local mirrored to Firebase for the signed-in active profile (spec-03, spec-05 §5.3).

@ProviderFor(collectionRepository)
final collectionRepositoryProvider = CollectionRepositoryProvider._();

/// Local-only, or local mirrored to Firebase for the signed-in active profile (spec-03, spec-05 §5.3).

final class CollectionRepositoryProvider
    extends
        $FunctionalProvider<
          CollectionRepository,
          CollectionRepository,
          CollectionRepository
        >
    with $Provider<CollectionRepository> {
  /// Local-only, or local mirrored to Firebase for the signed-in active profile (spec-03, spec-05 §5.3).
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
  $ProviderElement<CollectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CollectionRepository create(Ref ref) {
    return collectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionRepository>(value),
    );
  }
}

String _$collectionRepositoryHash() =>
    r'337847f16d798a9b833cfc181bfd6e6767c60167';
