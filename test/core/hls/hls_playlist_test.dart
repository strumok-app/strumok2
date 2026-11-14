import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/hls/hls_playlist.dart';

final _base = Uri.parse('https://cdn.example.com/video/index.m3u8?token=abc');

void main() {
  test('attribute lists keep commas inside quoted values', () {
    expect(parseHlsAttributes('BANDWIDTH=1280000,CODECS="avc1.4d401f,mp4a.40.2",RESOLUTION=1280x720'), {
      'BANDWIDTH': '1280000',
      'CODECS': 'avc1.4d401f,mp4a.40.2',
      'RESOLUTION': '1280x720',
    });
  });

  test('master playlist: variants and renditions with resolved URIs', () {
    const text = '''
\uFEFF#EXTM3U\r
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Українська",LANGUAGE="uk",URI="audio/uk.m3u8"\r
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Embedded",DEFAULT=YES\r
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",AUDIO="aud"\r
360p/index.m3u8\r
\r
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720\r
/abs/720p.m3u8?x=1\r
#EXT-X-STREAM-INF:BANDWIDTH=5000000\r
https://other.example.com/1080p.m3u8\r
''';
    final playlist = HlsPlaylist.parse(text, _base) as HlsMasterPlaylist;

    expect(playlist.variants.map((v) => v.uri.toString()), [
      'https://cdn.example.com/video/360p/index.m3u8',
      'https://cdn.example.com/abs/720p.m3u8?x=1',
      'https://other.example.com/1080p.m3u8',
    ]);
    expect(playlist.variants.map((v) => v.bandwidth), [800000, 2500000, 5000000]);
    expect(playlist.variants.first.codecs, 'avc1.4d401e,mp4a.40.2');
    expect(playlist.variants.first.audioGroup, 'aud');
    expect(playlist.renditions, hasLength(1));
    expect(playlist.renditions.single.uri.toString(), 'https://cdn.example.com/video/audio/uk.m3u8');
    expect(playlist.renditions.single.language, 'uk');
  });

  test('media playlist: sequence numbers, durations and fake-image segment names', () {
    const text = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:42
#EXTINF:9.976,
seg-0.png
#EXTINF:10.0,title
https://img.example.com/seg-1.jpg
#EXT-X-ENDLIST
''';
    final playlist = HlsPlaylist.parse(text, _base) as HlsMediaPlaylist;

    expect(playlist.mediaSequence, 42);
    expect(playlist.targetDuration, 10);
    expect(playlist.endList, isTrue);
    expect(playlist.segments.map((s) => s.uri.toString()), [
      'https://cdn.example.com/video/seg-0.png',
      'https://img.example.com/seg-1.jpg',
    ]);
    expect(playlist.segments.map((s) => s.sequence), [42, 43]);
    expect(playlist.segments.map((s) => s.duration), [9.976, 10.0]);
    expect(playlist.segments.every((s) => s.key == null && s.byteRange == null && !s.isFmp4), isTrue);
  });

  test('EXT-X-KEY applies until METHOD=NONE; IV parsed to 16 bytes', () {
    const text = '''
#EXTM3U
#EXTINF:4,
clear.ts
#EXT-X-KEY:METHOD=AES-128,URI="keys/k1.bin",IV=0x0102
#EXTINF:4,
enc1.ts
#EXT-X-KEY:METHOD=AES-128,URI="https://keys.example.com/k2"
#EXTINF:4,
enc2.ts
#EXT-X-KEY:METHOD=NONE
#EXTINF:4,
clear2.ts
''';
    final segments = (HlsPlaylist.parse(text, _base) as HlsMediaPlaylist).segments;

    expect(segments.map((s) => s.key?.method), [null, 'AES-128', 'AES-128', null]);
    expect(segments[1].key!.uri.toString(), 'https://cdn.example.com/video/keys/k1.bin');
    expect(segments[1].key!.iv, [...List.filled(14, 0), 1, 2]);
    expect(segments[2].key!.uri.toString(), 'https://keys.example.com/k2');
    expect(segments[2].key!.iv, isNull);
  });

  test('EXT-X-BYTERANGE applies to the next segment; missing offset continues the same resource', () {
    const text = '''
#EXTM3U
#EXTINF:4,
#EXT-X-BYTERANGE:1000@0
all.ts
#EXTINF:4,
#EXT-X-BYTERANGE:500
all.ts
#EXTINF:4,
#EXT-X-BYTERANGE:300
other.ts
#EXTINF:4,
plain.ts
''';
    final segments = (HlsPlaylist.parse(text, _base) as HlsMediaPlaylist).segments;

    expect(segments.map((s) => s.byteRange), [
      const HlsByteRange(length: 1000, offset: 0),
      const HlsByteRange(length: 500, offset: 1000),
      const HlsByteRange(length: 300, offset: 0),
      null,
    ]);
    expect(segments[1].byteRange!.rangeHeader, 'bytes=1000-1499');
  });

  test('EXT-X-MAP marks following segments as fMP4', () {
    const text = '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4",BYTERANGE="720@0"
#EXTINF:4,
seg1.m4s
#EXT-X-MAP:URI="init2.mp4"
#EXTINF:4,
seg2.m4s
''';
    final segments = (HlsPlaylist.parse(text, _base) as HlsMediaPlaylist).segments;

    expect(segments.every((s) => s.isFmp4), isTrue);
    expect(segments[0].map!.uri.toString(), 'https://cdn.example.com/video/init.mp4');
    expect(segments[0].map!.byteRange, const HlsByteRange(length: 720, offset: 0));
    expect(segments[1].map!.uri.toString(), 'https://cdn.example.com/video/init2.mp4');
  });

  test('rejects non-playlists', () {
    expect(() => HlsPlaylist.parse('<html></html>', _base), throwsFormatException);
    expect(() => HlsPlaylist.parse('', _base), throwsFormatException);
    expect(() => HlsPlaylist.parse('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,IV=0xZZ\n', _base), throwsFormatException);
  });
}
