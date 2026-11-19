import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/content_row.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../../../core/storage/offline_mode.dart';
import '../../collection/presentation/collection_items_row.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../downloads/data/offline_storage.dart';
import '../../downloads/domain/download_task.dart';
import '../../downloads/presentation/downloads_providers.dart';
import 'home_providers.dart';

/// Recommendations; in offline mode the downloaded contents instead (spec-08 §8.4).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineModeProvider)) return const _OfflineHome();

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

    // SPEC: "network unavailable" is detected as every recommendation row failing to load (no connectivity API).
    final allFailed =
        rows.isNotEmpty &&
        rows.every(
          (r) =>
              ref.watch(channelItemsProvider(r.supplier, r.channel).select((s) => s.error != null && s.items.isEmpty)),
        );
    final leading = [
      if (allFailed) const _OfflineSuggestion(),
      if (continueItems.isNotEmpty)
        CollectionItemsRow(title: context.l10n.homeContinue, items: continueItems, autofocusFirst: isTv),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: rows.length + leading.length,
      itemBuilder: (context, index) => index < leading.length
          ? leading[index]
          : _ChannelRow(row: rows[index - leading.length], autofocusFirst: isTv && index == 0),
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
    final notifier = ref.read(provider.notifier);
    return ContentRow(
      title: row.channel,
      subtitle: row.supplier,
      state: ref.watch(provider),
      onLoadMore: notifier.loadMore,
      onRetry: notifier.retry,
      onReload: notifier.reload,
      randomPool: notifier.randomPool,
      autofocusFirst: autofocusFirst,
    );
  }
}

/// Suggests offline mode when nothing could be loaded (spec-08 §8.4).
class _OfflineSuggestion extends ConsumerWidget {
  const _OfflineSuggestion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        key: const Key('offlineSuggestion'),
        color: colors.secondaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            spacing: 12,
            children: [
              Icon(Icons.cloud_off_outlined, color: colors.onSecondaryContainer),
              Expanded(
                child: Text(l10n.homeOfflineSuggestion, style: TextStyle(color: colors.onSecondaryContainer)),
              ),
              FilledButton(
                autofocus: true,
                onPressed: () => unawaited(ref.read(offlineModeProvider.notifier).set(true)),
                child: Text(l10n.offlineModeTurnOn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Downloaded content as a card row, after "Continue" limited to downloaded titles.
class _OfflineHome extends ConsumerWidget {
  const _OfflineHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final turnOff = FilledButton.tonal(
      autofocus: true,
      onPressed: () => unawaited(ref.read(offlineModeProvider.notifier).set(false)),
      child: Text(l10n.offlineModeTurnOff),
    );
    return switch (ref.watch(offlineContentsProvider)) {
      AsyncData(:final value) when value.isEmpty => EmptyStateView(
        icon: Icons.cloud_off_outlined,
        message: l10n.homeOfflineEmpty,
        action: turnOff,
      ),
      AsyncData(:final value) => _rows(context, ref, value, isTv),
      AsyncError(isLoading: false) => LoadErrorView(
        autofocus: true,
        onRetry: () => ref.invalidate(offlineContentsProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _rows(BuildContext context, WidgetRef ref, List<DownloadedContent> contents, bool isTv) {
    final downloaded = {for (final c in contents) c.key};
    final continueItems = [
      for (final item in ref.watch(continueWatchingProvider))
        if (downloaded.contains(downloadContentKey(item.supplier, item.id))) item,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (continueItems.isNotEmpty)
          CollectionItemsRow(title: context.l10n.homeContinue, items: continueItems, autofocusFirst: isTv),
        ContentRow.items(
          title: context.l10n.downloadsDownloaded,
          items: [for (final c in contents) _OfflineContentInfo(c)],
          autofocusFirst: isTv && continueItems.isEmpty,
        ),
      ],
    );
  }
}

class _OfflineContentInfo implements ContentInfo {
  final DownloadedContent content;

  const _OfflineContentInfo(this.content);

  @override
  String get id => content.id;
  @override
  String get supplier => content.supplier;
  @override
  String get title => content.details.title;
  @override
  String? get secondaryTitle => content.details.secondaryTitle;
  @override
  String get image => content.details.image;
}
