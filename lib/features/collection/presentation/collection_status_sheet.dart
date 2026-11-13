import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/side_sheet.dart';
import '../../../core/localization.dart';
import '../domain/collection_item.dart';
import '../domain/collection_query.dart';
import 'collection_labels.dart';
import 'collection_providers.dart';

Future<void> showCollectionStatusSheet(BuildContext context, ContentDetails details) => showSideSheet(
  context,
  title: context.l10n.navCollection,
  builder: (_) => CollectionStatusSheet(details: details),
);

/// Status (closes the sheet) and priority (only when in the collection, spec-03 §3.3).
class CollectionStatusSheet extends ConsumerWidget {
  final ContentDetails details;

  const CollectionStatusSheet({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final item = ref.watch(collectionItemProvider(details.supplier, details.id));
    final status = item?.status ?? CollectionStatus.none;
    final notifier = ref.read(collectionItemsProvider.notifier);

    void select(CollectionStatus value) {
      notifier.setStatus(details, value);
      Navigator.of(context).pop();
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        header(l10n.collectionStatusTitle),
        for (final value in collectionStatusOrder)
          ListTile(
            autofocus: value == (status == CollectionStatus.none ? collectionStatusOrder.first : status),
            selected: value == status,
            leading: Icon(collectionStatusIcon(value)),
            title: Text(l10n.collectionStatus(value)),
            trailing: value == status ? const Icon(Icons.check) : null,
            onTap: () => select(value),
          ),
        if (item != null) ...[
          ListTile(
            leading: const Icon(Icons.bookmark_remove_outlined),
            title: Text(l10n.collectionRemove),
            onTap: () => select(CollectionStatus.none),
          ),
          header(l10n.collectionPriorityTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final priority in CollectionPriority.values.reversed)
                  ChoiceChip(
                    label: Text(l10n.collectionPriority(priority)),
                    selected: item.priority == priority,
                    onSelected: (_) => notifier.setPriority(item.key, priority),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
