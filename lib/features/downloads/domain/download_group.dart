import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';

import 'download_task.dart';

/// Every queued, running or finished task of one content (spec-08 §8.1 content group), with the aggregate the UI
/// shows when a long series collapses into a single row. Pure, so it is unit-tested without IO.
@immutable
final class DownloadGroup {
  final String contentKey;
  final String title;
  final FileKind kind;
  final String image;

  /// Tasks of the content in ascending item order.
  final List<DownloadTask> tasks;

  const DownloadGroup({
    required this.contentKey,
    required this.title,
    required this.kind,
    required this.image,
    required this.tasks,
  });

  /// A content with a single enqueued item: shown as a plain task tile, not an expandable group.
  bool get single => tasks.length == 1;

  int get total => tasks.length;

  int get completed => tasks.where((t) => t.state == DownloadState.completed).length;

  int get failed => tasks.where((t) => t.state == DownloadState.failed).length;

  bool get hasActive => tasks.any((t) => t.state.active);

  bool get hasFinished => tasks.any((t) => !t.state.active);

  bool get hasRetryable => tasks.any((t) => t.state == DownloadState.failed || t.state == DownloadState.canceled);

  /// Combined speed of the running tasks, bytes per second.
  int get speed => tasks.where((t) => t.state == DownloadState.started).fold(0, (sum, t) => sum + t.speed);

  /// 0..1 across all items: completed count plus the fraction of the running ones.
  double get progress {
    if (tasks.isEmpty) return 0;
    var done = 0.0;
    for (final t in tasks) {
      done += switch (t.state) {
        DownloadState.completed => 1.0,
        DownloadState.started => t.progress.clamp(0, 1),
        _ => 0.0,
      };
    }
    return done / tasks.length;
  }

  /// The state shown for the whole group: running > waiting > done > failed > canceled.
  DownloadState get state {
    if (tasks.any((t) => t.state == DownloadState.started)) return DownloadState.started;
    if (tasks.any((t) => t.state == DownloadState.queued)) return DownloadState.queued;
    if (tasks.every((t) => t.state == DownloadState.completed)) return DownloadState.completed;
    if (tasks.any((t) => t.state == DownloadState.failed)) return DownloadState.failed;
    return DownloadState.canceled;
  }
}

/// Groups tasks by content and orders the groups: running first, then waiting, failed, canceled and finished; ties
/// keep enqueue order. Tasks within a group are ordered by item index.
List<DownloadGroup> groupDownloads(List<DownloadTask> tasks) {
  final byKey = <String, List<DownloadTask>>{};
  for (final task in tasks) {
    (byKey[task.contentKey] ??= []).add(task);
  }
  final groups = [
    for (final entry in byKey.entries)
      DownloadGroup(
        contentKey: entry.key,
        title: entry.value.first.request.title,
        kind: entry.value.first.request.kind,
        image: entry.value.first.request.image,
        tasks: [...entry.value]..sort((a, b) => a.request.itemIndex.compareTo(b.request.itemIndex)),
      ),
  ];

  int rank(DownloadGroup g) => switch (g.state) {
    DownloadState.started => 0,
    DownloadState.queued => 1,
    DownloadState.failed => 2,
    DownloadState.canceled => 3,
    DownloadState.completed => 4,
  };
  int firstSequence(DownloadGroup g) => g.tasks.map((t) => t.sequence).reduce(min);

  groups.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : firstSequence(a).compareTo(firstSequence(b));
  });
  return groups;
}
