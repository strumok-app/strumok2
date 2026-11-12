import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'http_client.dart';

typedef DownloadProgressCallback = void Function(int received, int? total);

class DownloadCanceledException implements Exception {
  const DownloadCanceledException();

  @override
  String toString() => 'Download canceled';
}

class DownloadCancelToken {
  final _completer = Completer<void>();

  bool get isCanceled => _completer.isCompleted;
  Future<void> get whenCanceled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Streams [uri] into `<target>.part` and renames it to [target] on success. The part file is removed on failure.
Future<void> downloadToFile(
  http.Client client,
  Uri uri,
  File target, {
  Map<String, String>? headers,
  DownloadProgressCallback? onProgress,
  DownloadCancelToken? cancelToken,
}) async {
  final part = File('${target.path}.part');
  await part.parent.create(recursive: true);

  IOSink? sink;
  StreamSubscription<List<int>>? subscription;
  try {
    if (cancelToken?.isCanceled ?? false) throw const DownloadCanceledException();

    final request = http.AbortableRequest('GET', uri, abortTrigger: cancelToken?.whenCanceled);
    if (headers != null) request.headers.addAll(headers);
    final response = await client.send(request).timeout(httpTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpStatusException(uri, response.statusCode);
    }

    final total = response.contentLength;
    var received = 0;
    sink = part.openWrite();
    final done = Completer<void>();

    subscription = response.stream
        .timeout(httpTimeout)
        .listen(
          (chunk) {
            sink!.add(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          },
          onError: (Object e, StackTrace st) {
            if (!done.isCompleted) done.completeError(e, st);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );

    unawaited(
      cancelToken?.whenCanceled.then((_) {
        if (!done.isCompleted) done.completeError(const DownloadCanceledException());
      }),
    );

    await done.future;
    await sink.flush();
    await sink.close();
    sink = null;
    await part.rename(target.path);
  } catch (_) {
    await subscription?.cancel();
    await sink?.close();
    if (part.existsSync()) await part.delete();
    if (cancelToken?.isCanceled ?? false) throw const DownloadCanceledException();
    rethrow;
  }
}
