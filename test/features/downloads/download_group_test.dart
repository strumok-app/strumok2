import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/downloads/domain/download_group.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';

DownloadRequest request(String content, int item, {FileKind kind = FileKind.video}) => DownloadRequest(
  supplier: 'alpha',
  contentId: content,
  itemIndex: item,
  title: content,
  itemTitle: 'Item ${item + 1}',
  kind: kind,
  sourceNames: const ['A'],
  root: '/downloads',
);

DownloadQueue enqueue(DownloadQueue queue, List<DownloadRequest> requests) => queue.apply(EnqueueDownloads(requests));

DownloadQueue set(DownloadQueue queue, String id, DownloadState state, {double progress = 0, int speed = 0}) =>
    queue.update(id, (t) => t.copyWith(state: state, progress: progress, speed: speed));

void main() {
  test('groups tasks by content, ordered by item index, single-item content flagged', () {
    final q = enqueue(const DownloadQueue(), [request('show', 2), request('show', 0), request('movie', 0)]);
    final groups = groupDownloads(q.tasks);

    final show = groups.firstWhere((g) => g.contentKey == 'alpha_show');
    expect(show.tasks.map((t) => t.request.itemIndex), [0, 2], reason: 'ascending item order');
    expect(show.total, 2);
    expect(show.single, isFalse);
    expect(groups.firstWhere((g) => g.contentKey == 'alpha_movie').single, isTrue);
  });

  test('aggregate progress, speed, counts and state', () {
    var q = enqueue(const DownloadQueue(), [request('s', 0), request('s', 1), request('s', 2), request('s', 3)]);
    q = set(q, 'alpha_s_0', DownloadState.completed);
    q = set(q, 'alpha_s_1', DownloadState.started, progress: 0.5, speed: 1000);
    q = set(q, 'alpha_s_2', DownloadState.failed);
    // alpha_s_3 stays queued.
    final group = groupDownloads(q.tasks).single;

    expect(group.completed, 1);
    expect(group.failed, 1);
    expect(group.progress, (1 + 0.5) / 4);
    expect(group.speed, 1000);
    expect(group.state, DownloadState.started, reason: 'a running task wins');
    expect(group.hasActive, isTrue);
    expect(group.hasRetryable, isTrue);
  });

  test('group state falls through running > queued > completed > failed > canceled', () {
    DownloadState stateOf(List<DownloadState> states) {
      var q = enqueue(const DownloadQueue(), [for (var i = 0; i < states.length; i++) request('s', i)]);
      for (var i = 0; i < states.length; i++) {
        q = set(q, 'alpha_s_$i', states[i]);
      }
      return groupDownloads(q.tasks).single.state;
    }

    expect(stateOf([DownloadState.queued, DownloadState.started]), DownloadState.started);
    expect(stateOf([DownloadState.completed, DownloadState.queued]), DownloadState.queued);
    expect(stateOf([DownloadState.completed, DownloadState.completed]), DownloadState.completed);
    expect(stateOf([DownloadState.completed, DownloadState.failed]), DownloadState.failed);
    expect(stateOf([DownloadState.canceled, DownloadState.canceled]), DownloadState.canceled);
  });

  test('groups are ordered running first, then by enqueue order', () {
    var q = enqueue(const DownloadQueue(), [request('a', 0)]);
    q = enqueue(q, [request('b', 0)]);
    q = enqueue(q, [request('c', 0)]);
    // Make the last-enqueued group the running one; it should float to the top.
    q = set(q, 'alpha_c_0', DownloadState.started);
    q = set(q, 'alpha_a_0', DownloadState.completed);

    expect(groupDownloads(q.tasks).map((g) => g.contentKey), ['alpha_c', 'alpha_b', 'alpha_a']);
  });
}
