import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strumok/app/widgets/trailing_fade.dart';

import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/content_row_frame.dart';
import '../../../app/widgets/random_pick_dialog.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../domain/collection_item.dart';
import '../domain/collection_query.dart';
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

  /// Header action picking a random item, high priority ones more often.
  final bool pickRandom;

  const CollectionItemsRow({
    super.key,
    required this.title,
    required this.items,
    this.autofocusFirst = false,
    this.pickRandom = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final cardWidth = isTv ? 160.0 : 136.0;

    return ContentRowFrame(
      title: title,
      label: '${items.length}',
      actions: [
        if (pickRandom)
          RowAction(
            key: const Key('rowPickRandom'),
            icon: Icons.casino_outlined,
            tooltip: l10n.rowPickRandom,
            onPressed: () => showRandomPickDialog(
              context,
              loadPool: () async => [for (final item in items) CollectionContentInfo(item)],
              weight: (info) => collectionPickWeight(info.item),
            ),
          ),
      ],
      body: SizedBox(
        height: cardWidth / posterAspectRatio + 72 + 2 * contentCardInset,
        child: TrailingFade(
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
      ),
    );
  }
}
