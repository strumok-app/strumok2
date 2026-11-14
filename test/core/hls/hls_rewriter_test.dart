import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/hls/hls_rewriter.dart';

final _base = Uri.parse('https://cdn.example.com/video/index.m3u8');

String seg(String url, {bool fmp4 = false, bool passthrough = false}) =>
    hlsProxySegmentPath(Uri.parse(url), fmp4: fmp4, passthrough: passthrough);

String stream(String url) => hlsProxyPlaylistPath('stream', Uri.parse(url));

List<String> rewrite(String text) => rewriteHlsPlaylist(text, _base).trimRight().split('\n');

void main() {
  test('master: variants and renditions go to /stream with absolute upstream URLs', () {
    final lines = rewrite('''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="uk",URI="audio/uk.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=800000,CODECS="avc1,mp4a"
360p/index.m3u8
#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=100000,URI="iframes.m3u8"
''');
    expect(lines, [
      '#EXTM3U',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="uk",URI="${stream('https://cdn.example.com/video/audio/uk.m3u8')}"',
      '#EXT-X-STREAM-INF:BANDWIDTH=800000,CODECS="avc1,mp4a"',
      stream('https://cdn.example.com/video/360p/index.m3u8'),
      '#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=100000,URI="${stream('https://cdn.example.com/video/iframes.m3u8')}"',
    ]);
  });

  test('media: segments go to /segment; tags are kept', () {
    final lines = rewrite('#EXTM3U\r\n#EXT-X-TARGETDURATION:10\r\n#EXTINF:10,\r\nseg0.png\r\n#EXT-X-ENDLIST\r\n');
    expect(lines, [
      '#EXTM3U',
      '#EXT-X-TARGETDURATION:10',
      '#EXTINF:10,',
      seg('https://cdn.example.com/video/seg0.png'),
      '#EXT-X-ENDLIST',
    ]);
  });

  test('encrypted segments pass through until METHOD=NONE; key URIs stay on the origin', () {
    final lines = rewrite('''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x01
#EXTINF:4,
enc.ts
#EXT-X-KEY:METHOD=NONE
#EXTINF:4,
clear.ts
''');
    expect(lines, [
      '#EXTM3U',
      '#EXT-X-KEY:METHOD=AES-128,URI="https://cdn.example.com/video/key.bin",IV=0x01',
      '#EXTINF:4,',
      seg('https://cdn.example.com/video/enc.ts', passthrough: true),
      '#EXT-X-KEY:METHOD=NONE',
      '#EXTINF:4,',
      seg('https://cdn.example.com/video/clear.ts'),
    ]);
  });

  test('EXT-X-BYTERANGE passes through only the next segment', () {
    final lines = rewrite('''
#EXTM3U
#EXTINF:4,
#EXT-X-BYTERANGE:100@0
all.ts
#EXTINF:4,
next.ts
''');
    expect(lines[3], seg('https://cdn.example.com/video/all.ts', passthrough: true));
    expect(lines[5], seg('https://cdn.example.com/video/next.ts'));
  });

  test('EXT-X-MAP switches the map and following segments to fmp4', () {
    final lines = rewrite('''
#EXTM3U
#EXT-X-MAP:URI="init.mp4",BYTERANGE="720@0"
#EXTINF:4,
seg1.m4s
''');
    expect(lines[1], '#EXT-X-MAP:URI="${seg('https://cdn.example.com/video/init.mp4', fmp4: true)}",BYTERANGE="720@0"');
    expect(lines[3], seg('https://cdn.example.com/video/seg1.m4s', fmp4: true));
  });
}
