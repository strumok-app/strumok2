import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'http_client.dart';

part 'image_cache.g.dart';

/// Disk cache for posters and pages; downloads go through the shared (HTTP/2) client.
@Riverpod(keepAlive: true)
BaseCacheManager imageCacheManager(Ref ref) {
  final manager = CacheManager(
    Config(
      'strumok_images',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 1000,
      fileService: HttpFileService(httpClient: ref.watch(httpClientProvider)),
    ),
  );
  ref.onDispose(manager.dispose);
  return manager;
}
