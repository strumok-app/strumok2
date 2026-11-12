// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Disk cache for posters and pages; downloads go through the shared (HTTP/2) client.

@ProviderFor(imageCacheManager)
final imageCacheManagerProvider = ImageCacheManagerProvider._();

/// Disk cache for posters and pages; downloads go through the shared (HTTP/2) client.

final class ImageCacheManagerProvider extends $FunctionalProvider<BaseCacheManager, BaseCacheManager, BaseCacheManager>
    with $Provider<BaseCacheManager> {
  /// Disk cache for posters and pages; downloads go through the shared (HTTP/2) client.
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

String _$imageCacheManagerHash() => r'b0f82a53d3c39a37777bc92e2123430ce25837be';
