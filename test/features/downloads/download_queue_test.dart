import 'dart:convert';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';

DownloadRequest request(String content, int item, {String supplier = 'alpha'}) => DownloadRequest(
  supplier: supplier,
  contentId: content,
  itemIndex: item,
  title: content,
  itemTitle: 'Episode ${item + 1}',
  kind: FileKind.video,
  sourceNames: const ['A'],
  sourceLanguages: const {'A': ContentLanguage.uk, 'Unknown': null},
  subtitleNames: const ['Subtitles', 'Alternative'],
  subtitleLanguages: const {'Subtitles': ContentLanguage.en, 'Alternative': ContentLanguage.uk},
  root: '/downloads',
);

DownloadQueue enqueue(DownloadQueue queue, List<DownloadRequest> requests) => queue.apply(EnqueueDownloads(requests));

/// Starts what the scheduler picks, as the engine does.
DownloadQueue startRunnable(DownloadQueue queue) {
  var next = queue;
  for (final task in queue.runnable()) {
    next = next.update(task.id, (t) => t.copyWith(state: DownloadState.started));
  }
  return next;
}

DownloadQueue finish(DownloadQueue queue, String id, [DownloadState state = DownloadState.completed]) =>
    queue.update(id, (t) => t.copyWith(state: state));

List<String> running(DownloadQueue queue) => [
  for (final t in queue.tasks)
    if (t.state == DownloadState.started) t.id,
];

void main() {
  test('task ids and content keys follow spec-08', () {
    expect(downloadTaskId('alpha', 'show/1', 3), 'alpha_show/1_3');
    expect(downloadContentKey('alpha', 'show/1'), 'alpha_show/1');
    expect(request('m1', 2).id, 'alpha_m1_2');
  });

  group('scheduler', () {
    test('a show downloads one episode at a time, in ascending order', () {
      var q = enqueue(const DownloadQueue(), [request('show', 2), request('show', 0), request('show', 1)]);
      q = startRunnable(q);
      expect(running(q), ['alpha_show_0']);

      q = startRunnable(finish(q, 'alpha_show_0'));
      expect(running(q), ['alpha_show_1']);

      // A failed episode does not stop the rest of the show.
      q = startRunnable(finish(q, 'alpha_show_1', DownloadState.failed));
      expect(running(q), ['alpha_show_2']);
    });

    test('different contents run in parallel up to the global limit, FIFO', () {
      var q = const DownloadQueue(maxConcurrent: 2);
      q = enqueue(q, [request('a', 0), request('a', 1)]);
      q = enqueue(q, [request('b', 0)]);
      q = enqueue(q, [request('c', 0)]);
      q = startRunnable(q);
      expect(running(q), ['alpha_a_0', 'alpha_b_0']);

      q = startRunnable(finish(q, 'alpha_b_0'));
      expect(running(q), ['alpha_a_0', 'alpha_c_0'], reason: 'c waited longer than the next episode of a');

      q = startRunnable(finish(q, 'alpha_a_0'));
      expect(running(q), ['alpha_a_1', 'alpha_c_0']);
    });

    test('a single episode joins its show group and keeps episode order', () {
      var q = enqueue(const DownloadQueue(), [request('show', 3), request('show', 4)]);
      q = startRunnable(q);
      q = enqueue(q, [request('show', 1)]);
      q = startRunnable(finish(q, 'alpha_show_3'));
      expect(running(q), ['alpha_show_1']);
    });

    test('nothing runs above the limit; raising the limit starts more', () {
      var q = const DownloadQueue(maxConcurrent: 1);
      q = startRunnable(enqueue(q, [request('a', 0), request('b', 0), request('c', 0)]));
      expect(running(q), hasLength(1));
      expect(q.runnable(), isEmpty);

      q = startRunnable(q.apply(const SetMaxConcurrentDownloads(3)));
      expect(running(q), hasLength(3));
    });

    test('the limit is clamped to 1..5', () {
      expect(const DownloadQueue().apply(const SetMaxConcurrentDownloads(9)).maxConcurrent, 5);
      expect(const DownloadQueue().apply(const SetMaxConcurrentDownloads(0)).maxConcurrent, 1);
      expect(const DownloadQueue().maxConcurrent, 3);
    });
  });

  group('commands', () {
    test('enqueue keeps active tasks and requeues finished ones', () {
      var q = startRunnable(enqueue(const DownloadQueue(), [request('a', 0), request('b', 0)]));
      q = finish(q, 'alpha_b_0', DownloadState.failed);
      q = enqueue(q, [request('a', 0), request('b', 0), request('b', 0)]);

      expect(q.tasks.map((t) => (t.id, t.state)), [
        ('alpha_a_0', DownloadState.started),
        ('alpha_b_0', DownloadState.queued),
      ]);
      expect(q['alpha_b_0']!.sequence, 2, reason: 'requeued at the back');
    });

    test('cancel per task, per content and all', () {
      var q = enqueue(const DownloadQueue(), [request('a', 0), request('a', 1), request('b', 0), request('c', 0)]);
      q = finish(q, 'alpha_c_0');
      q = q.apply(const CancelDownload('alpha_b_0'));
      expect(q['alpha_b_0']!.state, DownloadState.canceled);

      q = q.apply(const CancelContentDownloads('alpha_a'));
      expect([q['alpha_a_0']!.state, q['alpha_a_1']!.state], everyElement(DownloadState.canceled));

      q = enqueue(q, [request('d', 0)]).apply(const CancelAllDownloads());
      expect(q.idle, isTrue);
      expect(q['alpha_c_0']!.state, DownloadState.completed, reason: 'finished tasks are untouched');
    });

    test('retry queues failed and canceled tasks with their progress and place', () {
      var q = enqueue(const DownloadQueue(), [request('a', 0), request('b', 0)]);
      q = q.update('alpha_a_0', (t) => t.copyWith(state: DownloadState.failed, failure: DownloadFailure.network));
      q = q.update('alpha_a_0', (t) => t.copyWith(progress: 0.4));
      q = q.apply(const RetryDownload('alpha_a_0'));

      final task = q['alpha_a_0']!;
      expect(task.state, DownloadState.queued);
      expect(task.failure, isNull);
      expect(task.progress, 0.4);
      expect(startRunnable(q.apply(const SetMaxConcurrentDownloads(1))).tasks.first.state, DownloadState.started);
    });

    test('retry and dismiss per content affect only that group', () {
      var q = enqueue(const DownloadQueue(), [request('a', 0), request('a', 1), request('b', 0)]);
      q = finish(finish(q, 'alpha_a_0', DownloadState.failed), 'alpha_a_1', DownloadState.canceled);
      q = finish(q, 'alpha_b_0', DownloadState.failed);

      final retried = q.apply(const RetryContentDownloads('alpha_a'));
      expect([retried['alpha_a_0']!.state, retried['alpha_a_1']!.state], everyElement(DownloadState.queued));
      expect(retried['alpha_b_0']!.state, DownloadState.failed, reason: 'other groups untouched');

      final dismissed = q.apply(const DismissContentDownloads('alpha_a'));
      expect(dismissed.tasks.map((t) => t.id), ['alpha_b_0']);
    });

    test('dismiss per content keeps active tasks of the group', () {
      var q = startRunnable(enqueue(const DownloadQueue(maxConcurrent: 2), [request('a', 0), request('b', 0)]));
      q = enqueue(q, [request('a', 1)]);
      q = finish(q, 'alpha_a_0');
      final dismissed = q.apply(const DismissContentDownloads('alpha_a'));
      expect(dismissed['alpha_a_0'], isNull, reason: 'the finished episode is removed');
      expect(dismissed['alpha_a_1']!.state, DownloadState.queued, reason: 'the queued episode stays');
    });

    test('dismiss and clear remove only finished tasks', () {
      var q = enqueue(const DownloadQueue(), [request('a', 0), request('b', 0), request('c', 0)]);
      q = finish(finish(q, 'alpha_a_0'), 'alpha_b_0', DownloadState.canceled);
      expect(q.apply(const DismissDownload('alpha_c_0')).tasks, hasLength(3), reason: 'active');
      expect(q.apply(const DismissDownload('alpha_a_0')).tasks.map((t) => t.id), ['alpha_b_0', 'alpha_c_0']);
      expect(q.apply(const ClearFinishedDownloads()).tasks.map((t) => t.id), ['alpha_c_0']);
    });

    test('commands survive a JSON round trip', () {
      final commands = <DownloadCommand>[
        EnqueueDownloads([request('a', 0), request('b', 1)]),
        const CancelDownload('x'),
        const CancelContentDownloads('alpha_a'),
        const CancelAllDownloads(),
        const RetryDownload('x'),
        const RetryContentDownloads('alpha_a'),
        const DismissDownload('x'),
        const DismissContentDownloads('alpha_a'),
        const ClearFinishedDownloads(),
        const SetMaxConcurrentDownloads(4),
      ];
      final queue = enqueue(const DownloadQueue(), [request('a', 0)]);
      for (final command in commands) {
        expect(
          queue.apply(DownloadCommand.fromJson(jsonDecode(jsonEncode(command.toJson())) as Map<String, Object?>)),
          queue.apply(command),
        );
      }
    });
  });

  test('persistence: running tasks resume as queued, completed ones are dropped', () {
    var q = startRunnable(enqueue(const DownloadQueue(maxConcurrent: 2), [request('a', 0), request('b', 0)]));
    q = q.update('alpha_a_0', (t) => t.copyWith(progress: 0.5, speed: 1000));
    q = finish(q, 'alpha_b_0');
    q = enqueue(q, [
      request('c', 0),
    ]).update('alpha_c_0', (t) => t.copyWith(state: DownloadState.failed, failure: DownloadFailure.unavailable));

    final restored = DownloadQueue.fromJson(q.toJson());
    expect(restored, q);
    final resumed = restored.resumed();
    expect(resumed.tasks.map((t) => (t.id, t.state, t.progress, t.speed)), [
      ('alpha_a_0', DownloadState.queued, 0.5, 0),
      ('alpha_c_0', DownloadState.failed, 0.0, 0),
    ]);
    expect(resumed['alpha_c_0']!.failure, DownloadFailure.unavailable);
    expect(resumed.nextSequence, q.nextSequence);
  });

  test('persistence: a request saved with a single source name still loads', () {
    final json = request('a', 0).toJson()
      ..remove('sourceNames')
      ..remove('sourceLanguages')
      ..remove('subtitleNames')
      ..remove('subtitleLanguages')
      ..['subtitleName'] = 'Subtitles'
      ..['sourceName'] = 'Server 1';
    final restored = DownloadRequest.fromJson(json);
    expect(restored.sourceNames, ['Server 1']);
    expect(restored.sourceLanguages, isEmpty);
    expect(restored.subtitleNames, ['Subtitles']);
    expect(restored.subtitleLanguages, {'Subtitles': null});
  });

  test('persistence: subtitle priorities round-trip and legacy single-subtitle queues migrate', () {
    final original = request('a', 0);
    final json = jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>;
    final restored = DownloadRequest.fromJson(json);
    expect(restored, original);
    expect(restored.subtitleNames, ['Subtitles', 'Alternative']);
    expect(restored.subtitleLanguages, {'Subtitles': ContentLanguage.en, 'Alternative': ContentLanguage.uk});

    json
      ..remove('subtitleNames')
      ..remove('subtitleLanguages')
      ..['subtitleName'] = 'Old subtitles'
      ..['subtitleLanguage'] = 'uk';
    final legacy = DownloadRequest.fromJson(json);
    expect(legacy.subtitleNames, ['Old subtitles']);
    expect(legacy.subtitleLanguages, {'Old subtitles': ContentLanguage.uk});

    json['subtitleNames'] = <String>[];
    expect(
      DownloadRequest.fromJson(json).subtitleNames,
      isEmpty,
      reason: 'an explicit new choice wins over legacy data',
    );
  });
}
