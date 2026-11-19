import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../../../../core/platform/background_permissions.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/storage/offline_mode.dart';
import '../../domain/download_group.dart';
import '../../domain/download_queue.dart';
import '../../domain/download_task.dart';
import '../downloads_providers.dart';

/// Confirmation before deleting downloaded files; Cancel has the initial focus.
Future<bool> confirmDeleteDownload(BuildContext context, String title) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.downloadsDeleteConfirm(title)),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
        FilledButton.tonal(
          key: const Key('confirmDeleteDownload'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Before the first download (spec-08 §8.1): the notification permission, and once an explanation followed by the
/// system's battery-optimization request. No-op off Android.
Future<void> ensureDownloadPermissions(BuildContext context, WidgetRef ref) async {
  final permissions = ref.read(backgroundPermissionsProvider);
  final prefs = ref.read(appPreferencesProvider);
  await permissions.requestNotifications();
  if (prefs.getBool(AppPreferences.downloadsBatteryPromptShown) ?? false) return;
  if (!await permissions.canRequestBatteryExemption || !context.mounted) return;
  await prefs.setBool(AppPreferences.downloadsBatteryPromptShown, true);
  if (!context.mounted) return;
  final l10n = context.l10n;
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.downloadsBatteryTitle),
      content: Text(l10n.downloadsBatteryMessage),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonNotNow)),
        FilledButton(autofocus: true, onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonAllow)),
      ],
    ),
  );
  if (allow ?? false) await permissions.requestBatteryExemption();
}

/// Marks a downloaded (local) source in source lists.
class DownloadedMark extends StatelessWidget {
  const DownloadedMark({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.downloadsStateCompleted,
    child: Icon(Icons.download_done, size: 20, color: Theme.of(context).colorScheme.primary),
  );
}

/// Download state of one media item in the episode/chapter list: progress while downloading, an error mark when it
/// failed, and a delete button once downloaded.
class ItemDownloadStatus extends ConsumerWidget {
  final String supplier;
  final String id;
  final ContentMediaItem item;

  const ItemDownloadStatus({super.key, required this.supplier, required this.id, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final task = ref.watch(itemDownloadTaskProvider(supplier, id, item.number));
    final downloaded = ref.watch(
      offlineContentProvider(supplier, id).select((c) => c.value?.items.containsKey(item.number) ?? false),
    );
    if (task?.state == DownloadState.queued) {
      return Tooltip(
        message: l10n.downloadsStateQueued,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.schedule, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    if (task?.state == DownloadState.started) {
      return Tooltip(
        message: '${(task!.progress * 100).round()}%',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, value: task.progress > 0 ? task.progress : null),
          ),
        ),
      );
    }
    if (downloaded) {
      return IconButton(
        key: ValueKey('deleteDownload-${item.number}'),
        tooltip: l10n.downloadsDeleteContent,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final files = ref.read(offlineFilesProvider.notifier);
          if (!await confirmDeleteDownload(context, item.title)) return;
          await files.deleteItem(supplier, id, item.number);
        },
      );
    }
    if (task?.state == DownloadState.failed) {
      return Tooltip(
        message: downloadFailureLabel(l10n, task!.failure),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.error_outline, size: 20, color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// One task of the queue: titles, state or progress with speed, and its actions (cancel; retry / remove).
/// [compact] renders it as a nested item inside an expanded content group (item title only, indented).
class DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;
  final bool compact;

  const DownloadTaskTile({super.key, required this.task, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tasks = ref.read(downloadTasksProvider.notifier);
    final request = task.request;
    final status = switch (task.state) {
      DownloadState.queued => l10n.downloadsStateQueued,
      DownloadState.started => l10n.downloadsProgress(
        (task.progress * 100).round(),
        l10n.downloadsSpeed(formatBytes(l10n, task.speed)),
      ),
      DownloadState.completed => l10n.downloadsStateCompleted,
      DownloadState.failed => downloadFailureLabel(l10n, task.failure),
      DownloadState.canceled => l10n.downloadsStateCanceled,
    };
    void send(DownloadCommand command) => unawaited(tasks.send(command));

    final title = compact && request.itemTitle.isNotEmpty ? request.itemTitle : request.title;
    final detail = compact || request.itemTitle.isEmpty ? status : '${request.itemTitle} · $status';

    // Only the actions are focusable: D-pad users move between them, the row itself does nothing.
    return ListTile(
      key: downloadTaskKey(task.id),
      contentPadding: compact ? const EdgeInsets.only(left: 56, right: 8) : null,
      leading: compact ? null : Icon(request.kind == FileKind.manga ? Icons.menu_book_outlined : Icons.movie_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: task.state == DownloadState.failed ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          if (task.state == DownloadState.started)
            LinearProgressIndicator(
              value: task.progress > 0 ? task.progress : null,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.state.active)
            IconButton(
              key: ValueKey('cancelDownload-${task.id}'),
              tooltip: l10n.downloadsCancel,
              icon: const Icon(Icons.close),
              onPressed: () => send(CancelDownload(task.id)),
            ),
          if (task.state == DownloadState.failed || task.state == DownloadState.canceled)
            IconButton(
              key: ValueKey('retryDownload-${task.id}'),
              tooltip: l10n.commonRetry,
              icon: const Icon(Icons.refresh),
              onPressed: () => send(RetryDownload(task.id)),
            ),
          if (!task.state.active)
            IconButton(
              key: ValueKey('dismissDownload-${task.id}'),
              tooltip: l10n.downloadsDismiss,
              icon: const Icon(Icons.clear_all),
              onPressed: () => send(DismissDownload(task.id)),
            ),
        ],
      ),
    );
  }
}

/// A content with several queued/running items (e.g. a long series), collapsed to a single row: aggregate progress,
/// item counts and group-level actions. Activating the row (tap / D-pad Select) toggles its items.
class DownloadGroupTile extends ConsumerWidget {
  final DownloadGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final bool autofocus;

  const DownloadGroupTile({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tasks = ref.read(downloadTasksProvider.notifier);
    void send(DownloadCommand command) => unawaited(tasks.send(command));

    final status = switch (group.state) {
      DownloadState.queued => l10n.downloadsStateQueued,
      DownloadState.started => l10n.downloadsProgress(
        (group.progress * 100).round(),
        l10n.downloadsSpeed(formatBytes(l10n, group.speed)),
      ),
      DownloadState.completed => l10n.downloadsStateCompleted,
      DownloadState.failed => l10n.downloadsFailedCount(group.failed),
      DownloadState.canceled => l10n.downloadsStateCanceled,
    };

    return ListTile(
      key: downloadGroupKey(group.contentKey),
      autofocus: autofocus,
      onTap: onToggle,
      leading: Icon(group.kind == FileKind.manga ? Icons.menu_book_outlined : Icons.movie_outlined),
      title: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            '${l10n.downloadsGroupItems(group.completed, group.total)} · $status',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: group.state == DownloadState.failed ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          LinearProgressIndicator(
            value: group.state == DownloadState.started && group.progress <= 0 ? null : group.progress,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(expanded ? Icons.expand_less : Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
          if (group.hasActive)
            IconButton(
              key: ValueKey('cancelGroup-${group.contentKey}'),
              tooltip: l10n.downloadsCancel,
              icon: const Icon(Icons.close),
              onPressed: () => send(CancelContentDownloads(group.contentKey)),
            ),
          if (!group.hasActive && group.hasRetryable)
            IconButton(
              key: ValueKey('retryGroup-${group.contentKey}'),
              tooltip: l10n.commonRetry,
              icon: const Icon(Icons.refresh),
              onPressed: () => send(RetryContentDownloads(group.contentKey)),
            ),
          if (!group.hasActive)
            IconButton(
              key: ValueKey('dismissGroup-${group.contentKey}'),
              tooltip: l10n.downloadsDismiss,
              icon: const Icon(Icons.clear_all),
              onPressed: () => send(DismissContentDownloads(group.contentKey)),
            ),
        ],
      ),
    );
  }
}

/// Global offline mode (spec-08 §8.4), in the account menu.
class OfflineModeSwitch extends ConsumerWidget {
  final EdgeInsetsGeometry? contentPadding;

  const OfflineModeSwitch({super.key, this.contentPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SwitchListTile(
      key: const Key('offlineModeSwitch'),
      contentPadding: contentPadding,
      secondary: const Icon(Icons.cloud_off_outlined),
      title: Text(l10n.offlineMode),
      subtitle: Text(l10n.offlineModeDescription),
      value: ref.watch(offlineModeProvider),
      onChanged: (value) => unawaited(ref.read(offlineModeProvider.notifier).set(value)),
    );
  }
}
