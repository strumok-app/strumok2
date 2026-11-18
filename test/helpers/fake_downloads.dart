import 'dart:async';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:strumok/core/network/file_downloader.dart';
import 'package:strumok/features/downloads/data/download_engine.dart';
import 'package:strumok/features/downloads/data/media_download_runner.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';

/// Each run waits for the test to finish it.
class FakeRunner implements DownloadTaskRunner {
  final runs = <String, ({Completer<void> done, DownloadProgressReporter progress, DownloadCancelToken token})>{};
  final started = <String>[];

  @override
  Future<void> run(
    DownloadRequest request, {
    required DownloadProgressReporter onProgress,
    required DownloadCancelToken cancelToken,
  }) {
    final done = Completer<void>();
    runs[request.id] = (done: done, progress: onProgress, token: cancelToken);
    started.add(request.id);
    unawaited(
      cancelToken.whenCanceled.then((_) {
        if (!done.isCompleted) done.completeError(const DownloadCanceledException());
      }),
    );
    return done.future;
  }

  void complete(String id) => runs[id]!.done.complete();

  void fail(String id, Object error) => runs[id]!.done.completeError(error);
}

DownloadRequest downloadRequest(String content, int item, {String root = '/downloads'}) => DownloadRequest(
  supplier: 'alpha',
  contentId: content,
  itemIndex: item,
  title: content,
  itemTitle: '$item',
  kind: FileKind.video,
  sourceName: 'A',
  root: root,
);

/// Queue store without IO, for widget tests (real file IO does not complete in their fake-async zone).
class MemoryQueueStore extends DownloadQueueStore {
  DownloadQueue? saved;

  MemoryQueueStore([this.saved]) : super(File('/dev/null/queue.json'));

  @override
  Future<DownloadQueue> load() async => saved ?? const DownloadQueue();

  @override
  Future<void> save(DownloadQueue queue) async => saved = queue;

  @override
  Future<void> get flushed async {}
}
