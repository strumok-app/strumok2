import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../../suppliers/domain/supplier_config.dart';
import '../../suppliers/presentation/supplier_configs.dart';

/// Reorder (drag on touch/mouse, buttons on TV), enable and pick channels per supplier (spec-09 §7).
class SuppliersSettingsPage extends ConsumerWidget {
  const SuppliersSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final configs = ref.watch(supplierConfigsProvider);
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(l10n.settingsSuppliers, style: Theme.of(context).textTheme.headlineSmall),
    );

    if (configs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          Expanded(child: Center(child: Text(l10n.suppliersEmpty))),
        ],
      );
    }

    return ReorderableListView.builder(
      header: title,
      padding: const EdgeInsets.only(bottom: 16),
      buildDefaultDragHandles: false,
      itemCount: configs.length,
      onReorderItem: (oldIndex, newIndex) => ref.read(supplierConfigsProvider.notifier).move(oldIndex, newIndex),
      itemBuilder: (context, index) => _SupplierTile(
        key: ValueKey(configs[index].name),
        config: configs[index],
        index: index,
        count: configs.length,
        isTv: isTv,
      ),
    );
  }
}

class _SupplierTile extends ConsumerWidget {
  final SupplierConfig config;
  final int index;
  final int count;
  final bool isTv;

  const _SupplierTile({super.key, required this.config, required this.index, required this.count, required this.isTv});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notifier = ref.read(supplierConfigsProvider.notifier);
    final channels = config.supplier.channels.toList()..sort();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isTv)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.drag_handle)),
                  ),
                Expanded(child: Text(config.name, style: theme.textTheme.titleMedium)),
                if (isTv) ...[
                  IconButton(
                    tooltip: l10n.suppliersMoveUp,
                    onPressed: index > 0 ? () => notifier.move(index, index - 1) : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: l10n.suppliersMoveDown,
                    onPressed: index < count - 1 ? () => notifier.move(index, index + 1) : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                Switch(value: config.enabled, onChanged: (value) => notifier.setEnabled(config.name, value)),
              ],
            ),
            if (config.enabled && channels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.suppliersChannels, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final channel in channels)
                    FilterChip(
                      label: Text(channel),
                      selected: config.channels.contains(channel),
                      onSelected: (selected) => notifier.setChannel(config.name, channel, selected),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
