// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Disk cache for posters and other UI images; downloads go through the shared (HTTP/2) client.

@ProviderFor(imageCacheManager)
final imageCacheManagerProvider = ImageCacheManagerProvider._();

/// Disk cache for posters and other UI images; downloads go through the shared (HTTP/2) client.

final class ImageCacheManagerProvider extends $FunctionalProvider<BaseCacheManager, BaseCacheManager, BaseCacheManager>
    with $Provider<BaseCacheManager> {
  /// Disk cache for posters and other UI images; downloads go through the shared (HTTP/2) client.
  ImageCacheManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageCacheManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageCacheManagerHash();

  @$internal
  @override
  $ProviderElement<BaseCacheManager> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  BaseCacheManager create(Ref ref) {
    return imageCacheManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BaseCacheManager value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<BaseCacheManager>(value));
  }
}

String _$imageCacheManagerHash() => r'099431df202606be62b343db9f36f2bf725ee329';

/// Disk cache for manga pages; downloads go through the shared (HTTP/2) client.

@ProviderFor(mangaPageCacheManager)
final mangaPageCacheManagerProvider = MangaPageCacheManagerProvider._();

/// Disk cache for manga pages; downloads go through the shared (HTTP/2) client.

final class MangaPageCacheManagerProvider
    extends $FunctionalProvider<BaseCacheManager, BaseCacheManager, BaseCacheManager>
    with $Provider<BaseCacheManager> {
  /// Disk cache for manga pages; downloads go through the shared (HTTP/2) client.
  MangaPageCacheManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mangaPageCacheManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mangaPageCacheManagerHash();

  @$internal
  @override
  $ProviderElement<BaseCacheManager> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  BaseCacheManager create(Ref ref) {
    return mangaPageCacheManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BaseCacheManager value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<BaseCacheManager>(value));
  }
}

String _$mangaPageCacheManagerHash() => r'c7ddd502baf2120936efae6e08f3e1f5f50a2504';
