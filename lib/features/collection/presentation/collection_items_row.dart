import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/reveal_on_focus.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../domain/collection_item.dart';
import 'collection_labels.dart';

/// Collection entry as content for cards and details navigation.
class CollectionContentInfo implements ContentInfo {
  final CollectionItem item;

  const CollectionContentInfo(this.item);

  @override
  String get id => item.id;
  @override
  String get supplier => item.supplier;
  @override
  String get title => item.title;
  @override
  String? get secondaryTitle => null;
  @override
  String get image => item.image;
}

/// Horizontal row of collection cards with current item, progress and supplier badge.
class CollectionItemsRow extends ConsumerWidget {
  final String title;
  final List<CollectionItem> items;
  final bool autofocusFirst;

  const CollectionItemsRow({super.key, required this.title, required this.items, this.autofocusFirst = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final cardWidth = isTv ? 160.0 : 136.0;

    return RevealOnFocus(
      margin: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title),
                  TextSpan(
                    text: '  ${items.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              style: theme.textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: cardWidth / posterAspectRatio + 72 + 2 * contentCardInset,
            child: FocusTraversalGroup(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16 - contentCardInset, vertical: 8 - contentCardInset),
                clipBehavior: Clip.none,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12 - 2 * contentCardInset),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ContentCard(
                    info: CollectionContentInfo(item),
                    width: cardWidth,
                    autofocus: autofocusFirst && index == 0,
                    caption: l10n.collectionCurrentItem(item),
                    progress: item.currentPosition?.progress,
                    badge: item.supplier,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
