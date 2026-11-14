import 'dart:convert';
import 'dart:typed_data';

/// HLS playlist model (RFC 8216 subset needed by the proxy and downloads, spec-12).
sealed class HlsPlaylist {
  final Uri uri;

  const HlsPlaylist(this.uri);

  /// Parses [text] fetched from [uri]; relative URIs are resolved against [uri].
  /// Throws [FormatException] when the text is not an HLS playlist.
  factory HlsPlaylist.parse(String text, Uri uri) => _Parser(uri).parse(text);
}

final class HlsMasterPlaylist extends HlsPlaylist {
  final List<HlsVariant> variants;

  /// `EXT-X-MEDIA` renditions (alternative audio/subtitles); only those with a URI are kept.
  final List<HlsRendition> renditions;

  const HlsMasterPlaylist(super.uri, {required this.variants, this.renditions = const []});
}

final class HlsMediaPlaylist extends HlsPlaylist {
  final int mediaSequence;
  final int? targetDuration;
  final bool endList;
  final List<HlsSegment> segments;

  const HlsMediaPlaylist(
    super.uri, {
    required this.segments,
    this.mediaSequence = 0,
    this.targetDuration,
    this.endList = false,
  });
}

class HlsVariant {
  final Uri uri;
  final int? bandwidth;
  final String? resolution;
  final String? codecs;
  final String? audioGroup;

  const HlsVariant({required this.uri, this.bandwidth, this.resolution, this.codecs, this.audioGroup});
}

class HlsRendition {
  final Uri uri;
  final String type;
  final String? groupId;
  final String? name;
  final String? language;

  const HlsRendition({required this.uri, required this.type, this.groupId, this.name, this.language});
}

class HlsSegment {
  final Uri uri;
  final double duration;

  /// Media sequence number (also the default AES-128 IV, RFC 8216 §5.2).
  final int sequence;

  /// Encryption in effect for this segment; null when clear (no key or `METHOD=NONE`).
  final HlsKey? key;
  final HlsByteRange? byteRange;

  /// fMP4 initialization section; non-null means the segment is fMP4.
  final HlsMap? map;

  const HlsSegment({
    required this.uri,
    required this.duration,
    required this.sequence,
    this.key,
    this.byteRange,
    this.map,
  });

  bool get isFmp4 => map != null;
}

class HlsKey {
  final String method;
  final Uri? uri;

  /// 16-byte IV from the `IV` attribute; null means "use the media sequence number".
  final Uint8List? iv;
  final String? keyFormat;

  const HlsKey({required this.method, this.uri, this.iv, this.keyFormat});
}

class HlsByteRange {
  final int length;
  final int offset;

  const HlsByteRange({required this.length, required this.offset});

  int get end => offset + length;

  /// HTTP `Range` header value.
  String get rangeHeader => 'bytes=$offset-${end - 1}';

  @override
  bool operator ==(Object other) => other is HlsByteRange && other.length == length && other.offset == offset;

  @override
  int get hashCode => Object.hash(length, offset);

  @override
  String toString() => '$length@$offset';
}

class HlsMap {
  final Uri uri;
  final HlsByteRange? byteRange;

  const HlsMap({required this.uri, this.byteRange});
}

/// Parses an attribute list (`KEY=VALUE,KEY="quoted, value"`); quoted values are returned without quotes.
Map<String, String> parseHlsAttributes(String text) {
  final result = <String, String>{};
  var i = 0;
  while (i < text.length) {
    final eq = text.indexOf('=', i);
    if (eq < 0) break;
    final key = text.substring(i, eq).trim();
    var j = eq + 1;
    String value;
    if (j < text.length && text[j] == '"') {
      final close = text.indexOf('"', j + 1);
      final end = close < 0 ? text.length : close;
      value = text.substring(j + 1, end);
      j = close < 0 ? text.length : close + 1;
      final comma = text.indexOf(',', j);
      j = comma < 0 ? text.length : comma + 1;
    } else {
      final comma = text.indexOf(',', j);
      final end = comma < 0 ? text.length : comma;
      value = text.substring(j, end).trim();
      j = comma < 0 ? text.length : comma + 1;
    }
    if (key.isNotEmpty) result[key] = value;
    i = j;
  }
  return result;
}

class _Parser {
  final Uri base;

  _Parser(this.base);

  HlsPlaylist parse(String text) {
    final lines = const LineSplitter()
        .convert(text.startsWith('\uFEFF') ? text.substring(1) : text)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.first != '#EXTM3U') {
      throw const FormatException('Not an HLS playlist: missing #EXTM3U');
    }
    final isMaster = lines.any((l) => l.startsWith('#EXT-X-STREAM-INF:'));
    return isMaster ? _master(lines) : _media(lines);
  }

  HlsMasterPlaylist _master(List<String> lines) {
    final variants = <HlsVariant>[];
    final renditions = <HlsRendition>[];
    Map<String, String>? pending;
    for (final line in lines.skip(1)) {
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        pending = parseHlsAttributes(_value(line));
      } else if (line.startsWith('#EXT-X-MEDIA:')) {
        final a = parseHlsAttributes(_value(line));
        final uri = a['URI'];
        if (uri != null) {
          renditions.add(
            HlsRendition(
              uri: base.resolve(uri),
              type: a['TYPE'] ?? '',
              groupId: a['GROUP-ID'],
              name: a['NAME'],
              language: a['LANGUAGE'],
            ),
          );
        }
      } else if (!line.startsWith('#') && pending != null) {
        variants.add(
          HlsVariant(
            uri: base.resolve(line),
            bandwidth: int.tryParse(pending['BANDWIDTH'] ?? ''),
            resolution: pending['RESOLUTION'],
            codecs: pending['CODECS'],
            audioGroup: pending['AUDIO'],
          ),
        );
        pending = null;
      }
    }
    return HlsMasterPlaylist(base, variants: variants, renditions: renditions);
  }

  HlsMediaPlaylist _media(List<String> lines) {
    var mediaSequence = 0;
    int? targetDuration;
    var endList = false;
    final segments = <HlsSegment>[];

    double? duration;
    HlsKey? key;
    HlsMap? map;
    HlsByteRange? nextRange;
    // Byte ranges without an offset continue from the end of the previous range of the same resource.
    Uri? lastRangeUri;
    var lastRangeEnd = 0;

    for (final line in lines.skip(1)) {
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSequence = int.tryParse(_value(line)) ?? 0;
      } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        targetDuration = int.tryParse(_value(line));
      } else if (line == '#EXT-X-ENDLIST') {
        endList = true;
      } else if (line.startsWith('#EXTINF:')) {
        duration = double.tryParse(_value(line).split(',').first.trim()) ?? 0;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        key = _key(parseHlsAttributes(_value(line)));
      } else if (line.startsWith('#EXT-X-MAP:')) {
        final a = parseHlsAttributes(_value(line));
        final uri = a['URI'];
        if (uri == null) throw FormatException('EXT-X-MAP without URI: $line');
        final range = _byteRange(a['BYTERANGE']);
        map = HlsMap(
          uri: base.resolve(uri),
          byteRange: range == null || range.offset >= 0 ? range : HlsByteRange(length: range.length, offset: 0),
        );
      } else if (line.startsWith('#EXT-X-BYTERANGE:')) {
        nextRange = _byteRange(_value(line));
      } else if (!line.startsWith('#')) {
        final uri = base.resolve(line);
        HlsByteRange? range;
        if (nextRange != null) {
          range = nextRange.offset >= 0
              ? nextRange
              : HlsByteRange(length: nextRange.length, offset: uri == lastRangeUri ? lastRangeEnd : 0);
          lastRangeUri = uri;
          lastRangeEnd = range.end;
        }
        segments.add(
          HlsSegment(
            uri: uri,
            duration: duration ?? 0,
            sequence: mediaSequence + segments.length,
            key: key,
            byteRange: range,
            map: map,
          ),
        );
        duration = null;
        nextRange = null;
      }
    }
    return HlsMediaPlaylist(
      base,
      segments: segments,
      mediaSequence: mediaSequence,
      targetDuration: targetDuration,
      endList: endList,
    );
  }

  HlsKey? _key(Map<String, String> a) {
    final method = a['METHOD'] ?? 'NONE';
    if (method == 'NONE') return null;
    final uri = a['URI'];
    return HlsKey(
      method: method,
      uri: uri == null ? null : base.resolve(uri),
      iv: _iv(a['IV']),
      keyFormat: a['KEYFORMAT'],
    );
  }

  static Uint8List? _iv(String? hex) {
    if (hex == null) return null;
    var digits = hex.startsWith('0x') || hex.startsWith('0X') ? hex.substring(2) : hex;
    if (digits.length > 32 || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(digits)) {
      throw FormatException('Invalid EXT-X-KEY IV: $hex');
    }
    digits = digits.padLeft(32, '0');
    return Uint8List.fromList([for (var i = 0; i < 32; i += 2) int.parse(digits.substring(i, i + 2), radix: 16)]);
  }

  /// `<length>[@<offset>]`; a missing offset is returned as -1 (resolved by the caller).
  static HlsByteRange? _byteRange(String? value) {
    if (value == null) return null;
    final parts = value.split('@');
    final length = int.tryParse(parts[0].trim());
    final offset = parts.length > 1 ? int.tryParse(parts[1].trim()) : -1;
    if (length == null || offset == null) throw FormatException('Invalid byte range: $value');
    return HlsByteRange(length: length, offset: offset);
  }

  static String _value(String line) => line.substring(line.indexOf(':') + 1);
}
