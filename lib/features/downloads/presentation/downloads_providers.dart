import 'dart:async';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/network/http_client.dart';
import '../../../core/platform/app_paths.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/riverpod/cache_for.dart';
import '../../../core/storage/app_preferences.dart';
import '../../suppliers/data/supplier_registry.dart';
import '../data/android_download_service.dart';
import '../data/android_download_task.dart';
import '../data/download_engine.dart';
import '../data/download_resolver.dart';
import '../data/download_service.dart';
import '../data/local_sources.dart';
import '../data/media_download_runner.dart';
import '../data/offline_storage.dart';
import '../domain/download_queue.dart';
import '../domain/download_task.dart';

part 'downloads_providers.g.dart';

/// Downloads folder (spec-08 §8.3, spec-09 key `offline_downloads_directory`): user-selectable on desktop; a folder
/// that no longer exists falls back to the default.
@Riverpod(keepAlive: true)
class DownloadsFolder extends _$DownloadsFolder {
  @override
  Directory build() {
    final fallback = ref.watch(appPathsProvider).defaultDownloads;
    if (AppPlatform.current == AppPlatform.android) return fallback;
    final custom = ref.read(appPreferencesProvider).getString(AppPreferences.offlineDownloadsDirectory);
    if (custom == null) return fallback;
    final dir = Directory(custom);
    if (dir.existsSync()) return dir;
    unawaited(ref.read(appPreferencesProvider).remove(AppPreferences.offlineDownloadsDirectory));
    return fallback;
  }

  bool get isCustom => state.path != ref.read(appPathsProvider).defaultDownloads.path;

  Future<void> set(String path) async {
    state = Directory(path);
    await ref.read(appPreferencesProvider).setString(AppPreferences.offlineDownloadsDirectory, path);
  }

  Future<void> reset() async {
    state = ref.read(appPathsProvider).defaultDownloads;
    await ref.read(appPreferencesProvider).remove(AppPreferences.offlineDownloadsDirectory);
  }
}

/// Global concurrency limit (spec-08 §8.1: default 3, range 1–5).
@Riverpod(keepAlive: true)
class MaxParallelDownloads extends _$MaxParallelDownloads {
  @override
  int build() =>
      (ref.read(appPreferencesProvider).getInt(AppPreferences.downloadsMaxParallel) ??
              DownloadQueue.defaultMaxConcurrent)
          .clamp(DownloadQueue.minConcurrent, DownloadQueue.maxConcurrentLimit);

  Future<void> set(int value) async {
    state = value.clamp(DownloadQueue.minConcurrent, DownloadQueue.maxConcurrentLimit);
    await ref.read(appPreferencesProvider).setInt(AppPreferences.downloadsMaxParallel, state);
    final service = ref.read(downloadServiceProvider).value;
    await service?.send(SetMaxConcurrentDownloads(state));
  }
}

/// The download manager (spec-08 §8.1): an Android foreground service isolate, in-process elsewhere.
@Riverpod(keepAlive: true)
Future<DownloadService> downloadService(Ref ref) async {
  final paths = ref.watch(appPathsProvider);
  final store = DownloadQueueStore(paths.downloadQueue);
  final DownloadService service;
  if (AppPlatform.current == AppPlatform.android) {
    AppLocalizations l10n() => lookupAppLocalizations(ref.read(appLocaleProvider));
    PluginForegroundTaskApi.initialize(channelName: l10n().navDownloads);
    service = await AndroidDownloadService.create(
      store: store,
      api: PluginForegroundTaskApi(
        callback: downloadServiceMain,
        labels: () => (title: l10n().downloadsNotificationActive(1), cancelAll: l10n().downloadsCancelAll),
      ),
    );
  } else {
    final resolver = SupplierDownloadResolver(
      (name) => ref.read(suppliersProvider).where((s) => s.name == name).firstOrNull,
    );
    service = await InProcessDownloadService.start(
      DownloadEngine(
        store: store,
        runner: MediaDownloadRunner(client: ref.watch(httpClientProvider), resolver: resolver),
      ),
    );
  }
  ref.onDispose(() => unawaited(service.dispose()));
  final limit = ref.read(maxParallelDownloadsProvider);
  if (service.queue.maxConcurrent != limit) await service.send(SetMaxConcurrentDownloads(limit));
  return service;
}

/// Current queue; updates with throttled progress, so watch it with `select` outside the downloads page.
@Riverpod(keepAlive: true)
class DownloadTasks extends _$DownloadTasks {
  @override
  Future<DownloadQueue> build() async {
    final service = await ref.watch(downloadServiceProvider.future);
    final completed = <String>{
      for (final t in service.queue.tasks)
        if (t.state == DownloadState.completed) t.id,
    };
    final subscription = service.changes.listen((queue) {
      state = AsyncData(queue);
      // Finished files change what is available offline, only for their content.
      final refreshed = <String>{};
      for (final t in queue.tasks) {
        if (t.state == DownloadState.completed && completed.add(t.id) && refreshed.add(t.contentKey)) {
          refreshOfflineContent(ref, t.request.supplier, t.request.contentId);
        }
      }
    });
    ref.onDispose(subscription.cancel);
    return service.queue;
  }

  Future<void> send(DownloadCommand command) async => (await ref.read(downloadServiceProvider.future)).send(command);
}

/// Active (queued + running) tasks, for badges.
@riverpod
int activeDownloadCount(Ref ref) =>
    ref.watch(downloadTasksProvider.select((q) => q.value?.tasks.where((t) => t.state.active).length ?? 0));

/// The task of one media item, if any.
@riverpod
DownloadTask? itemDownloadTask(Ref ref, String supplier, String id, int itemIndex) {
  final taskId = downloadTaskId(supplier, id, itemIndex);
  return ref.watch(downloadTasksProvider.select((q) => q.value?[taskId]));
}

/// Bumped to scan everything again (e.g. files changed outside the app); single contents are refreshed with
/// [refreshOfflineContent].
@Riverpod(keepAlive: true)
class OfflineRevision extends _$OfflineRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

@Riverpod(keepAlive: true)
OfflineStorage offlineStorage(Ref ref) =>
    OfflineStorage(ref.watch(downloadsFolderProvider), suppliers: () => ref.read(suppliersProvider).map((s) => s.name));

// The offline providers are kept for a while so coming back to a page does not scan the folder again.
const _offlineCache = Duration(minutes: 5);

/// Downloaded contents, newest first (folders only).
@riverpod
Future<List<OfflineContentId>> offlineContentIds(Ref ref) {
  ref.cacheFor(_offlineCache);
  ref.watch(offlineRevisionProvider);
  return ref.watch(offlineStorageProvider).contentIds();
}

/// Details and finished items of one downloaded content.
@riverpod
Future<DownloadedContent?> offlineContent(Ref ref, String supplier, String id) {
  ref.cacheFor(_offlineCache);
  ref.watch(offlineRevisionProvider);
  return ref.watch(offlineStorageProvider).content(supplier, id);
}

/// Disk usage of one downloaded content; loaded apart from its items (it stats every file).
@riverpod
Future<int> offlineContentSize(Ref ref, String supplier, String id) {
  ref.cacheFor(_offlineCache);
  ref.watch(offlineRevisionProvider);
  return ref.watch(offlineStorageProvider).size(supplier, id);
}

/// Every downloaded content; one content refreshed with [refreshOfflineContent] is scanned again, the others come
/// from their cached [offlineContentProvider].
@riverpod
Future<List<DownloadedContent>> offlineContents(Ref ref) async {
  ref.cacheFor(_offlineCache);
  final ids = await ref.watch(offlineContentIdsProvider.future);
  final contents = await Future.wait([
    for (final (:supplier, :id) in ids) ref.watch(offlineContentProvider(supplier, id).future),
  ]);
  return contents.nonNulls.toList();
}

/// Scans one content again after its files changed; the list of contents only when [listChanged] or when it is new.
void refreshOfflineContent(Ref ref, String supplier, String id, {bool listChanged = false}) {
  ref
    ..invalidate(offlineContentProvider(supplier, id))
    ..invalidate(offlineContentSizeProvider(supplier, id));
  if (!ref.read(offlineContentIdsProvider.exists)) return;
  final known = ref.read(offlineContentIdsProvider).value?.contains((supplier: supplier, id: id)) ?? false;
  if (listChanged || !known) ref.invalidate(offlineContentIdsProvider);
}

/// Title of an offline item ("Episode N" / "Chapter N"; spec-08 §8.4).
String offlineItemTitle(AppLocalizations l10n, MediaType type, int number) =>
    type == MediaType.manga ? l10n.collectionChapter(number + 1) : l10n.collectionEpisode(number + 1);

/// Details of downloaded content in the current UI language.
OfflineContentDetails offlineContentDetails(Ref ref, DownloadedContent content) {
  final l10n = lookupAppLocalizations(ref.read(appLocaleProvider));
  return OfflineContentDetails(
    content,
    itemTitle: (number) => offlineItemTitle(l10n, content.details.mediaType, number),
  );
}

/// Deletes downloaded files after canceling their tasks, then refreshes what is available offline. Kept alive:
/// buttons call it with `ref.read` and the work continues after awaits.
@Riverpod(keepAlive: true)
class OfflineFiles extends _$OfflineFiles {
  @override
  void build() {}

  Future<void> deleteContent(String supplier, String id) async {
    final tasks = ref.read(downloadTasksProvider.notifier);
    await tasks.send(CancelContentDownloads(downloadContentKey(supplier, id)));
    final queue = ref.read(downloadTasksProvider).value;
    for (final t in queue?.tasks ?? const <DownloadTask>[]) {
      if (t.contentKey == downloadContentKey(supplier, id)) await tasks.send(DismissDownload(t.id));
    }
    await ref.read(offlineStorageProvider).deleteContent(supplier, id);
    refreshOfflineContent(ref, supplier, id, listChanged: true);
  }

  Future<void> deleteItem(String supplier, String id, int number) async {
    final tasks = ref.read(downloadTasksProvider.notifier);
    final taskId = downloadTaskId(supplier, id, number);
    await tasks.send(CancelDownload(taskId));
    await tasks.send(DismissDownload(taskId));
    await ref.read(offlineStorageProvider).deleteItem(supplier, id, number);
    // The content folder goes with its last item.
    refreshOfflineContent(ref, supplier, id, listChanged: true);
  }
}

/// Bytes as "1.2 GB" etc. in the UI language.
String formatBytes(AppLocalizations l10n, int bytes) {
  String one(double v) => v >= 100 ? v.round().toString() : v.toStringAsFixed(1);
  if (bytes >= 1 << 30) return l10n.sizeGigabytes(one(bytes / (1 << 30)));
  if (bytes >= 1 << 20) return l10n.sizeMegabytes(one(bytes / (1 << 20)));
  return l10n.sizeKilobytes(one(bytes / 1024));
}

/// Shown to the user for a failed task.
String downloadFailureLabel(AppLocalizations l10n, DownloadFailure? failure) => switch (failure) {
  DownloadFailure.network || null => l10n.downloadsFailureNetwork,
  DownloadFailure.unavailable => l10n.downloadsFailureUnavailable,
  DownloadFailure.sourceNotFound => l10n.downloadsFailureSourceNotFound,
  DownloadFailure.suppliers => l10n.downloadsFailureSuppliers,
  DownloadFailure.invalidMedia => l10n.downloadsFailureInvalidMedia,
  DownloadFailure.storage => l10n.downloadsFailureStorage,
};

/// Whether a source is a downloaded file (shown with a "downloaded" mark).
bool isLocalSource(Object source) => source is LocalMediaSource;

/// Locale-independent widget key helper for tests.
Key downloadTaskKey(String id) => ValueKey('downloadTask-$id');

/// Locale-independent widget key helper for a content download group.
Key downloadGroupKey(String contentKey) => ValueKey('downloadGroup-$contentKey');
