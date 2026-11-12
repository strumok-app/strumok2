import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/content_row.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import 'home_providers.dart';

// SPEC: the "Continue" row (spec-01 Home) needs the collection and arrives with M3; offline Home with M8.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeRowsProvider);
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;

    if (rows.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: rows.length,
      itemBuilder: (context, index) => _ChannelRow(row: rows[index], autofocusFirst: isTv && index == 0),
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
