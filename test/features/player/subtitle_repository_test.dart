import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/features/player/data/subtitle_repository.dart';

import '../../helpers/fake_player.dart';

void main() {
  const srt = '1\n00:00:01,000 --> 00:00:02,000\nПривіт\n';

  test('fetches with the source headers, parses in an isolate, caches by key', () async {
    final requests = <http.Request>[];
    final repository = SubtitleRepository(
      MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(srt), 200);
      }),
    );
    final source = FakeSubtitleSource('UA', headers: {'Referer': 'https://site.example/'});

    final track = await repository.load('k1', source);
    expect(track.linesAt(const Duration(milliseconds: 1500)), ['Привіт']);
    expect(requests.single.url.toString(), 'https://subs.example.com/UA.vtt');
    expect(requests.single.headers['Referer'], 'https://site.example/');

    await repository.load('k1', source);
    expect(requests, hasLength(1), reason: 'cached');
    await repository.load('k2', source);
    expect(requests, hasLength(2));
  });

  test('HTTP errors fail and are not cached', () async {
    var status = 404;
    final repository = SubtitleRepository(MockClient((_) async => http.Response.bytes(utf8.encode(srt), status)));
    final source = FakeSubtitleSource('UA');

    await expectLater(repository.load('k', source), throwsA(isA<http.ClientException>()));
    status = 200;
    expect((await repository.load('k', source)).cues, hasLength(1));
  });
}
