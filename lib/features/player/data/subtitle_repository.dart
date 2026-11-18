import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/http_client.dart';
import '../domain/subtitles.dart';
import 'subtitle_decoding.dart';

part 'subtitle_repository.g.dart';

typedef SubtitleParser = Future<SubtitleTrack> Function(Uint8List bytes);

@Riverpod(keepAlive: true)
SubtitleRepository subtitleRepository(Ref ref) => SubtitleRepository(ref.watch(httpClientProvider));

/// Decoding and parsing a whole file is CPU work: keep it off the UI isolate.
Future<SubtitleTrack> parseSubtitleBytesInIsolate(Uint8List bytes) =>
    Isolate.run(() => parseSubtitles(decodeSubtitleBytes(bytes)), debugName: 'subtitles');

/// Supplier subtitles (spec-06 §6.5): fetched with the source headers over the shared client, decoded and parsed in
/// a separate isolate; parsed tracks of recent items are kept in memory.
class SubtitleRepository {
  static const _capacity = 16;

  final http.Client _client;
  final SubtitleParser _parse;

  /// Insertion-ordered: the first entry is the least recently used.
  final _cache = <String, Future<SubtitleTrack>>{};

  SubtitleRepository(this._client, [this._parse = parseSubtitleBytesInIsolate]);

  /// [key] identifies (supplier, id, item, subtitle name); failed loads are not cached.
  Future<SubtitleTrack> load(String key, SubtitleMediaItemSource source) {
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;

    final future = _fetch(source);
    _cache[key] = future;
    if (_cache.length > _capacity) _cache.remove(_cache.keys.first);
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_cache[key], future)) _cache.remove(key);
        },
      ),
    );
    return future;
  }

  Future<SubtitleTrack> _fetch(SubtitleMediaItemSource source) async {
    final link = await source.link;
    // Downloaded subtitles (spec-08 §8.4).
    if (link.scheme == 'file') return _parse(await File.fromUri(link).readAsBytes());
    final response = await _client.get(link, headers: source.headers);
    if (response.statusCode >= 400) {
      throw http.ClientException('Subtitles request failed: HTTP ${response.statusCode}', response.request?.url);
    }
    return _parse(response.bodyBytes);
  }
}

String subtitleCacheKey(String supplier, String id, int item, String name) => '$supplier|$id|$item|$name';
