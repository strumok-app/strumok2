import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/side_sheet.dart';
import '../../../core/content_labels.dart';
import '../../../core/localization.dart';
import '../../suppliers/presentation/supplier_configs.dart';
import 'search_providers.dart';

/// Filters apply immediately; the sheet only needs closing.
Future<void> showSearchFiltersSheet(BuildContext context) =>
    showSideSheet(context, title: context.l10n.searchFilters, builder: (_) => const SearchFiltersSheet());

class SearchFiltersSheet extends ConsumerWidget {
  const SearchFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filters = ref.watch(searchFiltersProvider);
    final notifier = ref.read(searchFiltersProvider.notifier);
    final suppliers = [
      for (final c in ref.watch(supplierConfigsProvider))
        if (c.enabled) c.name,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _FilterGroup(
          title: l10n.searchFilterLanguages,
          chips: [
            for (final (index, language) in ContentLanguage.values.indexed)
              FilterChip(
                autofocus: index == 0,
                label: Text(l10n.contentLanguage(language)),
                selected: filters.languages.contains(language),
                onSelected: (_) => notifier.toggleLanguage(language),
              ),
          ],
        ),
        _FilterGroup(
          title: l10n.searchFilterTypes,
          chips: [
            for (final type in ContentType.values)
              FilterChip(
                label: Text(l10n.contentType(type)),
                selected: filters.types.contains(type),
                onSelected: (_) => notifier.toggleType(type),
              ),
          ],
        ),
        _FilterGroup(
          title: l10n.searchFilterSuppliers,
          chips: [
            FilterChip(
              key: const Key('searchAllSuppliersChip'),
              label: Text(l10n.searchFilterSuppliersAll),
              selected: filters.suppliers.isEmpty,
              onSelected: (_) => notifier.setSupplierSelection(const {}),
            ),
            for (final name in suppliers)
              FilterChip(
                label: Text(name),
                selected: filters.suppliers.contains(name),
                onSelected: (_) => notifier.toggleSupplier(name),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<Widget> chips;

  const _FilterGroup({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) => Padding(
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
}
