import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/core/network/file_downloader.dart';
import 'package:strumok/core/network/http_client.dart';

void main() {
  late Directory dir;
  late File target;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('strumok_dl');
    target = File('${dir.path}/sub/file.bin');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final uri = Uri.parse('https://example.com/file.bin');

  test('writes the file, reports progress and forwards headers', () async {
    Map<String, String>? sentHeaders;
    final client = MockClient.streaming((request, _) async {
      sentHeaders = request.headers;
      return http.StreamedResponse(
        Stream.fromIterable([List.filled(10, 1), List.filled(5, 2)]),
        200,
        contentLength: 15,
      );
    });
    final progress = <int>[];

    await downloadToFile(client, uri, target, headers: {'User-Agent': 'x'}, onProgress: (r, _) => progress.add(r));

    expect(target.readAsBytesSync(), hasLength(15));
    expect(progress, [10, 15]);
    expect(sentHeaders?['User-Agent'], 'x');
    expect(File('${target.path}.part').existsSync(), isFalse);
  });

  test('HTTP error leaves no files', () async {
    final client = MockClient((_) async => http.Response('nope', 404));

    await expectLater(downloadToFile(client, uri, target), throwsA(isA<HttpStatusException>()));
    expect(target.existsSync(), isFalse);
    expect(File('${target.path}.part').existsSync(), isFalse);
  });

  test('cancel stops the download and removes the part file', () async {
    final controller = StreamController<List<int>>();
    final client = MockClient.streaming((_, _) async => http.StreamedResponse(controller.stream, 200));
    final token = DownloadCancelToken();

    final future = downloadToFile(client, uri, target, cancelToken: token);
    controller.add([1, 2, 3]);
    await Future<void>.delayed(Duration.zero);
    token.cancel();

    await expectLater(future, throwsA(isA<DownloadCanceledException>()));
    expect(target.existsSync(), isFalse);
    expect(File('${target.path}.part').existsSync(), isFalse);
    unawaited(controller.close());
  });
}
