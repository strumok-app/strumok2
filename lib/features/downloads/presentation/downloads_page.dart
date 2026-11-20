import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/app_network_image.dart';
import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../data/offline_storage.dart';
import '../domain/download_group.dart';
import '../domain/download_queue.dart';
import '../domain/download_task.dart';
import 'downloads_providers.dart';
import 'widgets/download_widgets.dart';

/// Downloads, split into a "Queue" tab (tasks grouped by content, long series collapsed to one expandable row) and a
/// "Downloaded" tab, so the finished contents stay reachable no matter how long the queue grows (spec-08 §8.1, §8.3).
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> with TickerProviderStateMixin {
  late final TabController _tabs;

  /// Content groups whose items are shown expanded.
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toggle(String contentKey) =>
      setState(() => _expanded.contains(contentKey) ? _expanded.remove(contentKey) : _expanded.add(contentKey));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final queue = ref.watch(downloadTasksProvider).value ?? const DownloadQueue();
    final contents = ref.watch(offlineContentsProvider);
    final activeCount = queue.tasks.where((t) => t.state.active).length;
    final downloadedCount = contents.value?.length ?? 0;
    final hasTasks = queue.tasks.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.navDownloads, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          // With nothing queued, drop the tabs and show the downloaded contents directly.
          if (hasTasks) ...[
            TabBar(
              controller: _tabs,
              tabs: [
                _TabLabel(label: l10n.downloadsQueue, count: activeCount),
                _TabLabel(label: l10n.downloadsDownloaded, count: downloadedCount),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _QueueTab(queue: queue, expanded: _expanded, onToggle: _toggle),
                  _DownloadedTab(contents),
                ],
              ),
            ),
          ] else
            Expanded(child: _DownloadedTab(contents)),
        ],
      ),
    );
  }
}

/// A tab label with a count badge for the active / downloaded totals.
class _TabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (count > 0) Badge(label: Text('$count')),
      ],
    ),
  );
}

/// Queue tab: global actions on top, then the content groups in a lazy list. A multi-item group is one row with
/// aggregate progress; expanding it adds its items to the same list, so even a series of hundreds stays lazy.
class _QueueTab extends ConsumerWidget {
  final DownloadQueue queue;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;

  const _QueueTab({required this.queue, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (queue.tasks.isEmpty) {
      return EmptyStateView(icon: Icons.schedule_outlined, message: l10n.downloadsQueueEmpty);
    }

    final groups = groupDownloads(queue.tasks);
    final hasActive = groups.any((g) => g.hasActive);
    final hasFinished = groups.any((g) => g.hasFinished);
    final notifier = ref.read(downloadTasksProvider.notifier);

    final rows = <_QueueRow>[];
    for (final group in groups) {
      if (group.single) {
        rows.add(_TaskRow(group.tasks.first));
      } else {
        rows.add(_GroupRow(group));
        if (expanded.contains(group.contentKey)) {
          rows.addAll(group.tasks.map(_ItemRow.new));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: rows.length,
            itemBuilder: (context, index) => switch (rows[index]) {
              _TaskRow(:final task) => DownloadTaskTile(task: task),
              _GroupRow(:final group) => DownloadGroupTile(
                group: group,
                expanded: expanded.contains(group.contentKey),
                onToggle: () => onToggle(group.contentKey),
              ),
              _ItemRow(:final task) => DownloadTaskTile(task: task, compact: true),
            },
          ),
        ),
      ],
    );
  }
}

/// A row of the flattened queue list.
sealed class _QueueRow {
  const _QueueRow();
}

/// A single-item content, shown as a plain task tile.
final class _TaskRow extends _QueueRow {
  final DownloadTask task;

  const _TaskRow(this.task);
}

/// The collapsible header of a multi-item content group.
final class _GroupRow extends _QueueRow {
  final DownloadGroup group;

  const _GroupRow(this.group);
}

/// One expanded item of a content group.
final class _ItemRow extends _QueueRow {
  final DownloadTask task;

  const _ItemRow(this.task);
}

/// Downloaded tab: the finished contents in a lazy list.
class _DownloadedTab extends StatelessWidget {
  final AsyncValue<List<DownloadedContent>> contents;

  const _DownloadedTab(this.contents);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Value-first: keep showing the downloaded contents while the list reloads (a download just finished) instead of
    // replacing them with a spinner; the loader only shows on the first load.
    return switch (contents) {
      AsyncValue(:final value?) when value.isEmpty => EmptyStateView(
        icon: Icons.download_outlined,
        message: l10n.downloadsEmpty,
      ),
      AsyncValue(:final value?) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: value.length,
        itemBuilder: (context, index) => _ContentTile(content: value[index], autofocus: index == 0),
      ),
      AsyncError(isLoading: false) => Consumer(
        builder: (context, ref, _) =>
            LoadErrorView(autofocus: true, onRetry: () => ref.invalidate(offlineContentsProvider)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
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
          final files = ref.read(offlineFilesProvider.notifier);
          if (!await confirmDeleteDownload(context, details.title)) return;
          await files.deleteContent(content.supplier, content.id);
        },
      ),
    );
  }
}
