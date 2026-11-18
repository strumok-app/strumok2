import 'package:flutter/foundation.dart';

import 'download_task.dart';

/// Changes to the download queue; JSON-encodable so they can cross into the Android service isolate.
sealed class DownloadCommand {
  const DownloadCommand();

  Map<String, Object?> toJson();

  static DownloadCommand fromJson(Map<String, Object?> json) => switch (json['type']) {
    'enqueue' => EnqueueDownloads([
      for (final r in json['requests'] as List) DownloadRequest.fromJson((r as Map).cast<String, Object?>()),
    ]),
    'cancel' => CancelDownload(json['id'] as String),
    'cancelContent' => CancelContentDownloads(json['contentKey'] as String),
    'cancelAll' => const CancelAllDownloads(),
    'retry' => RetryDownload(json['id'] as String),
    'dismiss' => DismissDownload(json['id'] as String),
    'clearFinished' => const ClearFinishedDownloads(),
    'maxConcurrent' => SetMaxConcurrentDownloads((json['value'] as num).toInt()),
    final type => throw FormatException('Unknown download command: $type'),
  };
}

/// Already active tasks are kept; finished ones (failed, canceled, completed) are queued again.
final class EnqueueDownloads extends DownloadCommand {
  final List<DownloadRequest> requests;

  const EnqueueDownloads(this.requests);

  @override
  Map<String, Object?> toJson() => {
    'type': 'enqueue',
    'requests': [for (final r in requests) r.toJson()],
  };
}

final class CancelDownload extends DownloadCommand {
  final String id;

  const CancelDownload(this.id);

  @override
  Map<String, Object?> toJson() => {'type': 'cancel', 'id': id};
}

/// Cancels every active task of one content (spec-08: per group).
final class CancelContentDownloads extends DownloadCommand {
  final String contentKey;

  const CancelContentDownloads(this.contentKey);

  @override
  Map<String, Object?> toJson() => {'type': 'cancelContent', 'contentKey': contentKey};
}

final class CancelAllDownloads extends DownloadCommand {
  const CancelAllDownloads();

  @override
  Map<String, Object?> toJson() => {'type': 'cancelAll'};
}

/// Queues a failed or canceled task again; it keeps its place in the queue and resumes partial files.
final class RetryDownload extends DownloadCommand {
  final String id;

  const RetryDownload(this.id);

  @override
  Map<String, Object?> toJson() => {'type': 'retry', 'id': id};
}

/// Removes a finished task from the list.
final class DismissDownload extends DownloadCommand {
  final String id;

  const DismissDownload(this.id);

  @override
  Map<String, Object?> toJson() => {'type': 'dismiss', 'id': id};
}

final class ClearFinishedDownloads extends DownloadCommand {
  const ClearFinishedDownloads();

  @override
  Map<String, Object?> toJson() => {'type': 'clearFinished'};
}

final class SetMaxConcurrentDownloads extends DownloadCommand {
  final int value;

  const SetMaxConcurrentDownloads(this.value);

  @override
  Map<String, Object?> toJson() => {'type': 'maxConcurrent', 'value': value};
}

/// Persistent download queue and scheduling rules (spec-08 §8.1); pure, so the scheduler is unit-tested without IO.
@immutable
final class DownloadQueue {
  static const minConcurrent = 1;
  static const maxConcurrentLimit = 5;
  static const defaultMaxConcurrent = 3;

  /// In enqueue order.
  final List<DownloadTask> tasks;
  final int maxConcurrent;
  final int nextSequence;

  const DownloadQueue({this.tasks = const [], this.maxConcurrent = defaultMaxConcurrent, this.nextSequence = 0});

  /// No task queued or running.
  bool get idle => !tasks.any((t) => t.state.active);

  DownloadTask? operator [](String id) => tasks.where((t) => t.id == id).firstOrNull;

  DownloadQueue apply(DownloadCommand command) => switch (command) {
    EnqueueDownloads(:final requests) => _enqueue(requests),
    CancelDownload(:final id) => _cancelWhere((t) => t.id == id),
    CancelContentDownloads(:final contentKey) => _cancelWhere((t) => t.contentKey == contentKey),
    CancelAllDownloads() => _cancelWhere((_) => true),
    RetryDownload(:final id) => _map(
      (t) => t.id == id && (t.state == DownloadState.failed || t.state == DownloadState.canceled)
          ? t.copyWith(state: DownloadState.queued, speed: 0, clearFailure: true)
          : t,
    ),
    DismissDownload(:final id) => _copy(
      tasks: [
        for (final t in tasks)
          if (t.id != id || t.state.active) t,
      ],
    ),
    ClearFinishedDownloads() => _copy(
      tasks: [
        for (final t in tasks)
          if (t.state.active) t,
      ],
    ),
    SetMaxConcurrentDownloads(:final value) => _copy(maxConcurrent: value.clamp(minConcurrent, maxConcurrentLimit)),
  };

  /// Tasks to start now: FIFO across content groups, at most one running task per group (taking its lowest
  /// item index first), within the global limit.
  List<DownloadTask> runnable() {
    final running = tasks.where((t) => t.state == DownloadState.started).toList();
    final slots = maxConcurrent - running.length;
    if (slots <= 0) return const [];
    final busy = {for (final t in running) t.contentKey};

    final next = <String, DownloadTask>{};
    final order = <String, int>{};
    for (final task in tasks) {
      if (task.state != DownloadState.queued || busy.contains(task.contentKey)) continue;
      final group = task.contentKey;
      order[group] = order[group] == null || task.sequence < order[group]! ? task.sequence : order[group]!;
      final current = next[group];
      if (current == null || task.request.itemIndex < current.request.itemIndex) next[group] = task;
    }
    final groups = order.keys.toList()..sort((a, b) => order[a]!.compareTo(order[b]!));
    return [for (final group in groups.take(slots)) next[group]!];
  }

  DownloadQueue update(String id, DownloadTask Function(DownloadTask task) change) =>
      _map((t) => t.id == id ? change(t) : t);

  /// After an app or service restart: running tasks are queued again (their partial files resume) and completed
  /// ones are dropped (the files on disk represent them).
  DownloadQueue resumed() => _copy(
    tasks: [
      for (final t in tasks)
        if (t.state == DownloadState.started)
          t.copyWith(state: DownloadState.queued, speed: 0)
        else if (t.state != DownloadState.completed)
          t,
    ],
  );

  factory DownloadQueue.fromJson(Map<String, Object?> json) => DownloadQueue(
    tasks: [for (final t in json['tasks'] as List? ?? const []) DownloadTask.fromJson((t as Map).cast())],
    maxConcurrent: ((json['maxConcurrent'] as num?)?.toInt() ?? defaultMaxConcurrent).clamp(
      minConcurrent,
      maxConcurrentLimit,
    ),
    nextSequence: (json['nextSequence'] as num?)?.toInt() ?? 0,
  );

  Map<String, Object?> toJson() => {
    'tasks': [for (final t in tasks) t.toJson()],
    'maxConcurrent': maxConcurrent,
    'nextSequence': nextSequence,
  };

  DownloadQueue _enqueue(List<DownloadRequest> requests) {
    var sequence = nextSequence;
    final byId = {for (final t in tasks) t.id: t};
    final added = <String>{};
    for (final request in requests) {
      final existing = byId[request.id];
      if ((existing != null && existing.state.active) || added.contains(request.id)) continue;
      byId[request.id] = DownloadTask(request: request, sequence: sequence++);
      added.add(request.id);
    }
    final kept = [
      for (final t in tasks)
        if (!added.contains(t.id)) t,
    ];
    return _copy(tasks: [...kept, for (final id in added) byId[id]!], nextSequence: sequence);
  }

  DownloadQueue _cancelWhere(bool Function(DownloadTask task) test) =>
      _map((t) => t.state.active && test(t) ? t.copyWith(state: DownloadState.canceled, speed: 0) : t);

  DownloadQueue _map(DownloadTask Function(DownloadTask task) change) =>
      _copy(tasks: [for (final t in tasks) change(t)]);

  DownloadQueue _copy({List<DownloadTask>? tasks, int? maxConcurrent, int? nextSequence}) => DownloadQueue(
    tasks: tasks ?? this.tasks,
    maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    nextSequence: nextSequence ?? this.nextSequence,
  );

  @override
  bool operator ==(Object other) =>
      other is DownloadQueue &&
      listEquals(other.tasks, tasks) &&
      other.maxConcurrent == maxConcurrent &&
      other.nextSequence == nextSequence;

  @override
  int get hashCode => Object.hash(Object.hashAll(tasks), maxConcurrent, nextSequence);
}
