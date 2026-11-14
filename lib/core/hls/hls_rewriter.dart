import 'dart:convert';

import 'hls_playlist.dart';

/// Rewrites a playlist so every playlist/segment request goes through the local HLS proxy (spec-12 §12.4).
/// Returned URIs are root-relative (`/stream?url=…`), so the player resolves them against the proxy origin.
String rewriteHlsPlaylist(String text, Uri base) {
  final lines = const LineSplitter().convert(text.startsWith('\uFEFF') ? text.substring(1) : text);
  final isMaster = lines.any((l) => l.trimLeft().startsWith('#EXT-X-STREAM-INF:'));

  var encrypted = false;
  var fmp4 = false;
  var nextByteRange = false;
  final out = StringBuffer();

  for (final raw in lines) {
    final line = raw.trim();
    var rewritten = line;
    if (line.startsWith('#')) {
      if (line.startsWith('#EXT-X-KEY:')) {
        encrypted = (parseHlsAttributes(_value(line))['METHOD'] ?? 'NONE') != 'NONE';
        // SPEC: keys stay on the origin; relative key URIs are made absolute so they don't resolve to the proxy.
        rewritten = _replaceUri(line, (uri) => base.resolve(uri).toString());
      } else if (line.startsWith('#EXT-X-BYTERANGE:')) {
        nextByteRange = true;
      } else if (line.startsWith('#EXT-X-MAP:')) {
        fmp4 = true;
        rewritten = _replaceUri(line, (uri) => hlsProxySegmentPath(base.resolve(uri), fmp4: true));
      } else if (line.startsWith('#EXT-X-MEDIA:') || line.startsWith('#EXT-X-I-FRAME-STREAM-INF:')) {
        rewritten = _replaceUri(line, (uri) => hlsProxyPlaylistPath('stream', base.resolve(uri)));
      }
    } else if (line.isNotEmpty) {
      final uri = base.resolve(line);
      rewritten = isMaster
          ? hlsProxyPlaylistPath('stream', uri)
          : hlsProxySegmentPath(uri, fmp4: fmp4, passthrough: encrypted || nextByteRange);
      nextByteRange = false;
    }
    out.writeln(rewritten);
  }
  return out.toString();
}

String hlsProxyPlaylistPath(String endpoint, Uri upstream) =>
    Uri(path: '/$endpoint', queryParameters: {'url': upstream.toString()}).toString();

String hlsProxySegmentPath(Uri upstream, {bool fmp4 = false, bool passthrough = false}) => Uri(
  path: '/segment',
  queryParameters: {'url': upstream.toString(), if (fmp4) 'format': 'fmp4', if (passthrough) 'passthrough': 'true'},
).toString();

final _uriAttribute = RegExp(r'URI="([^"]*)"');

String _replaceUri(String line, String Function(String uri) replace) =>
    line.replaceFirstMapped(_uriAttribute, (m) => 'URI="${replace(m[1]!)}"');

String _value(String line) => line.substring(line.indexOf(':') + 1);
