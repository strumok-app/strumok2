import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/content_row.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../../collection/presentation/collection_items_row.dart';
import '../../collection/presentation/collection_providers.dart';
import 'home_providers.dart';

// SPEC: offline Home (downloaded content) arrives with M8.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeRowsProvider);
    final continueItems = ref.watch(continueWatchingProvider);
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;

    if (rows.isEmpty && continueItems.isEmpty) {
      return EmptyStateView(
        icon: Icons.tune,
        message: context.l10n.homeEmpty,
        action: FilledButton.tonal(
          autofocus: true,
          onPressed: () => context.push(AppRoutes.settingsSuppliers),
          child: Text(context.l10n.homeConfigure),
        ),
      );
    }

    final offset = continueItems.isEmpty ? 0 : 1;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: rows.length + offset,
      itemBuilder: (context, index) => index < offset
          ? CollectionItemsRow(title: context.l10n.homeContinue, items: continueItems, autofocusFirst: isTv)
          : _ChannelRow(row: rows[index - offset], autofocusFirst: isTv && index == 0),
    );
  }
}

class _ChannelRow extends ConsumerWidget {
  final HomeRow row;
  final bool autofocusFirst;

  const _ChannelRow({required this.row, required this.autofocusFirst});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = channelItemsProvider(row.supplier, row.channel);
    return ContentRow(
      title: row.channel,
      subtitle: row.supplier,
      state: ref.watch(provider),
      onLoadMore: ref.read(provider.notifier).loadMore,
      onRetry: ref.read(provider.notifier).retry,
      autofocusFirst: autofocusFirst,
    );
  }
}
