import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/app_network_image.dart';
import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../data/offline_storage.dart';
import '../domain/download_queue.dart';
import '../domain/download_task.dart';
import 'downloads_providers.dart';
import 'widgets/download_widgets.dart';

/// Download queue with progress, speed and actions, then the downloaded contents (spec-08 §8.1, §8.3).
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final queue = ref.watch(downloadTasksProvider).value ?? const DownloadQueue();
    final contents = ref.watch(offlineContentsProvider);
    final tasks = _ordered(queue.tasks);
    final hasActive = tasks.any((t) => t.state.active);
    final hasFinished = tasks.any((t) => !t.state.active);
    final notifier = ref.read(downloadTasksProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.navDownloads, style: theme.textTheme.headlineSmall),
        if (tasks.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.downloadsQueue,
            actions: [
              if (hasActive)
                TextButton(
                  key: const Key('cancelAllDownloads'),
                  autofocus: true,
                  onPressed: () => unawaited(notifier.send(const CancelAllDownloads())),
                  child: Text(l10n.downloadsCancelAll),
                ),
              if (hasFinished)
                TextButton(
                  key: const Key('clearFinishedDownloads'),
                  autofocus: !hasActive,
                  onPressed: () => unawaited(notifier.send(const ClearFinishedDownloads())),
                  child: Text(l10n.downloadsClearFinished),
                ),
            ],
          ),
          SurfaceZone(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [for (final task in tasks) DownloadTaskTile(task: task)]),
          ),
        ],
        _SectionHeader(title: l10n.downloadsDownloaded),
        switch (contents) {
          AsyncData(:final value) when value.isEmpty => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: EmptyStateView(icon: Icons.download_outlined, message: l10n.downloadsEmpty),
          ),
          AsyncData(:final value) => SurfaceZone(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (index, content) in value.indexed)
                  _ContentTile(content: content, autofocus: tasks.isEmpty && index == 0),
              ],
            ),
          ),
          AsyncError(isLoading: false) => LoadErrorView(
            autofocus: tasks.isEmpty,
            onRetry: () => ref.invalidate(offlineContentsProvider),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }

  /// Running first, then waiting, then finished; enqueue order within each.
  static List<DownloadTask> _ordered(List<DownloadTask> tasks) {
    int rank(DownloadTask t) => switch (t.state) {
      DownloadState.started => 0,
      DownloadState.queued => 1,
      DownloadState.failed => 2,
      DownloadState.canceled => 3,
      DownloadState.completed => 4,
    };
    return [...tasks]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.sequence.compareTo(b.sequence);
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const _SectionHeader({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Poster, title, items and size; opens the details, delete asks first.
class _ContentTile extends ConsumerWidget {
  final DownloadedContent content;
  final bool autofocus;

  const _ContentTile({required this.content, required this.autofocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final details = content.details;
    final count = content.items.length;
    final items = details.mediaType == MediaType.manga ? l10n.downloadsChapters(count) : l10n.downloadsEpisodes(count);
    return ListTile(
      key: ValueKey('downloadedContent-${content.key}'),
      autofocus: autofocus,
      leading: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: SizedBox(width: 40, height: 40 / posterAspectRatio, child: AppNetworkImage(details.image)),
      ),
      title: Text(details.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('$items · ${formatBytes(l10n, content.sizeBytes)} · ${content.supplier}'),
      onTap: () => context.push(AppRoutes.details(content.supplier, content.id)),
      trailing: IconButton(
        key: ValueKey('deleteContent-${content.key}'),
        tooltip: l10n.downloadsDeleteContent,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          if (!await confirmDeleteDownload(context, details.title)) return;
          await ref.read(offlineFilesProvider.notifier).deleteContent(content.supplier, content.id);
        },
      ),
    );
  }
}
