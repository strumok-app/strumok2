import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'http_client.dart';

part 'image_cache.g.dart';

/// Posters, thumbnails and avatars: few, small and shown again and again.
const imageCacheMaxObjects = 1000;
const imageCacheStalePeriod = Duration(days: 14);

/// Manga pages: many large files (often 0.3–2 MB) usually read once, kept briefly and apart from the other images
/// so reading never evicts posters. The count bounds the disk use (no byte limit in `flutter_cache_manager`).
const mangaPageCacheMaxObjects = 500;
const mangaPageCacheStalePeriod = Duration(days: 3);

/// Disk cache for posters and other UI images; downloads go through the shared (HTTP/2) client.
@Riverpod(keepAlive: true)
BaseCacheManager imageCacheManager(Ref ref) => _cacheManager(
  ref,
  'strumok_images',
  stalePeriod: imageCacheStalePeriod,
  maxObjects: imageCacheMaxObjects,
  client: ref.watch(httpClientProvider),
);

/// Disk cache for manga pages; downloads go through the shared (HTTP/2) client.
@Riverpod(keepAlive: true)
BaseCacheManager mangaPageCacheManager(Ref ref) => _cacheManager(
  ref,
  'strumok_manga_pages',
  stalePeriod: mangaPageCacheStalePeriod,
  maxObjects: mangaPageCacheMaxObjects,
  client: ref.watch(httpClientProvider),
);

/// Least recently used files beyond [maxObjects], and files unused for [stalePeriod], are deleted.
BaseCacheManager _cacheManager(
  Ref ref,
  String key, {
  required Duration stalePeriod,
  required int maxObjects,
  required http.Client client,
}) {
  final manager = CacheManager(
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxObjects,
      fileService: HttpFileService(httpClient: client),
    ),
  );
  ref.onDispose(manager.dispose);
  return manager;
}
