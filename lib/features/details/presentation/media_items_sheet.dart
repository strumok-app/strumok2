import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/side_sheet.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../downloads/presentation/widgets/download_widgets.dart';
import 'details_providers.dart';
import 'details_widgets.dart';
import 'media_items_list.dart';

Future<void> showMediaItemsSheet(BuildContext context, ContentDetails details) => showSideSheet(
  context,
  title: details.mediaType == MediaType.video ? context.l10n.detailsEpisodes : context.l10n.detailsChapters,
  builder: (_) => MediaItemsSheet(details: details),
);

/// Episodes/chapters of [details] with progress from the collection (when the content is in it) and their download
/// state, with per-item delete (spec-08 §8.3).
class MediaItemsSheet extends ConsumerWidget {
  final ContentDetails details;

  const MediaItemsSheet({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = mediaItemsProvider(details.supplier, details.id);
    final collectionItem = ref.watch(collectionItemProvider(details.supplier, details.id));

    // Value-first: keep the list on screen while the provider reloads (e.g. a download just finished) instead of
    // flashing a spinner; only show the loader on the very first load.
    return switch (ref.watch(provider)) {
      AsyncValue(:final value?) when value.isEmpty => EmptyStateView(icon: Icons.list, message: l10n.rowEmpty),
      AsyncValue(:final value?) => MediaItemsList(
        items: value,
        mediaType: details.mediaType,
        positions: collectionItem?.positions ?? const {},
        currentItem: collectionItem?.currentItem,
        trailing: (item) => ItemDownloadStatus(supplier: details.supplier, id: details.id, item: item),
        onSelected: (item) {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(mediaItemRoute(details, item: item.number));
        },
      ),
      AsyncError(isLoading: false) => LoadErrorView(autofocus: true, onRetry: () => ref.invalidate(provider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
