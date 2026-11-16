import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/side_sheet.dart';
import '../../../app/widgets/state_views.dart';
import '../../../app/widgets/text_field_arrow_escape.dart';
import '../../../core/content_labels.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../domain/collection_query.dart';
import 'collection_items_row.dart';
import 'collection_labels.dart';
import 'collection_providers.dart';

/// Status groups with title search and filters (spec-01 Collection).
class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  late final _controller = TextEditingController(text: ref.read(collectionFilterProvider).query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final items = ref.watch(collectionItemsProvider);
    final groups = ref.watch(collectionGroupsProvider);

    final Widget body = switch (items) {
      AsyncError(isLoading: false) => LoadErrorView(onRetry: () => ref.invalidate(collectionItemsProvider)),
      AsyncData(:final value) when value.isEmpty => EmptyStateView(
        icon: Icons.favorite_border,
        message: l10n.collectionEmpty,
      ),
      AsyncData() when groups.isEmpty => EmptyStateView(icon: Icons.search_off, message: l10n.searchNothingFound),
      AsyncData() => ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: groups.length,
        itemBuilder: (context, index) => CollectionItemsRow(
          title: l10n.collectionStatus(groups[index].$1),
          items: groups[index].$2,
          autofocusFirst: isTv && index == 0,
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextFieldArrowEscape(
                  controller: _controller,
                  child: TextField(
                    controller: _controller,
                    onChanged: ref.read(collectionFilterProvider.notifier).setQuery,
                    decoration: InputDecoration(
                      hintText: l10n.collectionSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.searchClear,
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _controller.clear();
                                ref.read(collectionFilterProvider.notifier).setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('collectionFiltersButton'),
                tooltip: l10n.searchFilters,
                icon: const Icon(Icons.tune),
                onPressed: () =>
                    showSideSheet(context, title: l10n.searchFilters, builder: (_) => const _CollectionFiltersSheet()),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _CollectionFiltersSheet extends ConsumerWidget {
  const _CollectionFiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(collectionFilterProvider);
    final notifier = ref.read(collectionFilterProvider.notifier);

    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          FocusTraversalGroup(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        group(l10n.collectionStatusTitle, [
          for (final (index, status) in collectionStatusOrder.indexed)
            FilterChip(
              autofocus: index == 0,
              label: Text(l10n.collectionStatus(status)),
              selected: filter.statuses.contains(status),
              onSelected: (_) => notifier.toggleStatus(status),
            ),
        ]),
        group(l10n.collectionFilterMediaType, [
          for (final type in MediaType.values)
            FilterChip(
              label: Text(l10n.mediaType(type)),
              selected: filter.mediaTypes.contains(type),
              onSelected: (_) => notifier.toggleMediaType(type),
            ),
        ]),
        group(l10n.searchFilterSuppliers, [
          for (final supplier in ref.watch(collectionSuppliersProvider))
            FilterChip(
              label: Text(supplier),
              selected: filter.suppliers.contains(supplier),
              onSelected: (_) => notifier.toggleSupplier(supplier),
            ),
        ]),
      ],
    );
  }
}
