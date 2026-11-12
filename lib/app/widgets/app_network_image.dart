import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/image_cache.dart';

/// Network image loaded through the shared client and disk cache; tonal placeholder on load/error.
class AppNetworkImage extends ConsumerWidget {
  final String url;
  final Map<String, String>? headers;
  final BoxFit fit;

  const AppNetworkImage(this.url, {super.key, this.headers, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(color: colors.surfaceContainerHighest);
    if (Uri.tryParse(url)?.hasScheme != true) return placeholder;

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      cacheManager: ref.watch(imageCacheManagerProvider),
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(child: Icon(Icons.image_not_supported_outlined, color: colors.onSurfaceVariant)),
      ),
    );
  }
}
