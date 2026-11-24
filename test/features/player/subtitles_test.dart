import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/player/data/subtitle_decoding.dart';
import 'package:strumok/features/player/domain/subtitles.dart';

Duration ms(int value) => Duration(milliseconds: value);

const vtt = '''WEBVTT
Kind: captions

NOTE a comment
with --> nothing

STYLE
::cue { color: yellow }

intro
00:01.000 --> 00:03.500 align:start position:10%
<v Roger>Hello <b>there</b></v>
<c.yellow>second</c> line

00:00:04.000 --> 00:00:06.000
&lt;tag&gt; &amp; <00:00:05.000>karaoke

00:00:07.000 --> 00:00:06.000
end before start

bad --> timing
skipped
''';

const srt = '''1
00:00:01,000 --> 00:00:02,500
<i>Привіт</i>, {\\an8}світе

2
00:00:02,000 --> 00:00:04,000
<font color="#ffff00">Друга</font>
репліка

3
00:00:05,000 --> 00:00:06,000

4
not a timing
text
''';

void main() {
  group('parseSubtitles', () {
    test('WebVTT: header, NOTE/STYLE blocks, cue ids and settings, tags and entities', () {
      final track = parseSubtitles(vtt);
      expect(track.cues, [
        SubtitleCue(ms(1000), ms(3500), 'Hello there\nsecond line'),
        SubtitleCue(ms(4000), ms(6000), '<tag> & karaoke'),
      ]);
    });

    test('SRT: comma millis, HTML and ASS tags; empty and malformed cues skipped', () {
      final track = parseSubtitles(srt);
      expect(track.cues, [
        SubtitleCue(ms(1000), ms(2500), 'Привіт, світе'),
        SubtitleCue(ms(2000), ms(4000), 'Друга\nрепліка'),
      ]);
    });

    test('ASS: parses dialogue timing and preserves text commas and line breaks', () {
      const ass = r'''; generated subtitles
[Script Info]
ScriptType: v4.00+

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Comment: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,Not displayed
Dialogue: 0,0:00:01.25,0:00:03.50,Default,,0,0,0,,{\an8}Hello, <friend>!\NSecond\nline
Dialogue: 0,0:00:02.00,0:00:03.00,Default,,0,0,0,,{\p1}m 0 0 l 40 40{\p0}Visible\htext
Dialogue: 0,0:00:02.00,0:00:03.00,Default,,0,0,0,,{\p1}m 0 0 l 40 40
Dialogue: 0,0:00:05.00,0:00:04.00,Default,,0,0,0,,Invalid timing
Dialogue: 0,0:00:01.00,0:00:02.00,Missing fields

[Fonts]
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,Outside Events
''';
      final track = parseSubtitles('\uFEFF${ass.replaceAll('\n', '\r\n')}');
      expect(track.cues, [
        SubtitleCue(ms(1250), ms(3500), 'Hello, <friend>!\nSecond line'),
        SubtitleCue(ms(2000), ms(3000), 'Visible\u00A0text'),
      ]);
      expect(track.linesAt(ms(1249)), isEmpty);
      expect(track.linesAt(ms(2500)), ['Hello, <friend>!', 'Second line', 'Visible\u00A0text']);
      expect(track.linesAt(ms(3500)), isEmpty);
    });

    test('CRLF line endings and a BOM', () {
      final track = parseSubtitles('\uFEFF${srt.replaceAll('\n', '\r\n')}');
      expect(track.cues, hasLength(2));
    });

    test('cues are sorted by start', () {
      final track = parseSubtitles('00:00:05,000 --> 00:00:06,000\nB\n\n00:00:01,000 --> 00:00:02,000\nA\n');
      expect(track.cues.map((c) => c.text), ['A', 'B']);
    });
  });

  group('SubtitleTrack.linesAt', () {
    final track = parseSubtitles(srt);

    test('active cues, overlapping ones in start order', () {
      expect(track.linesAt(ms(500)), isEmpty);
      expect(track.linesAt(ms(1000)), ['Привіт, світе']);
      expect(track.linesAt(ms(2200)), ['Привіт, світе', 'Друга', 'репліка']);
      expect(track.linesAt(ms(2500)), ['Друга', 'репліка'], reason: 'end is exclusive');
      expect(track.linesAt(ms(4500)), isEmpty);
    });

    test('offset: positive shows subtitles later, negative earlier', () {
      expect(track.linesAt(ms(1500), offset: ms(1000)), isEmpty);
      expect(track.linesAt(ms(2000), offset: ms(1000)), ['Привіт, світе']);
      expect(track.linesAt(ms(500), offset: ms(-1000)), ['Привіт, світе']);
    });

    test('a long early cue is still found behind later short ones', () {
      final long = SubtitleTrack([
        SubtitleCue(ms(0), ms(10000), 'long'),
        for (var i = 1; i < 9; i++) SubtitleCue(ms(i * 1000), ms(i * 1000 + 100), 'short $i'),
      ]);
      expect(long.linesAt(ms(8500)), ['long']);
    });
  });

  group('decodeSubtitleBytes', () {
    test('UTF-8 with and without BOM', () {
      expect(decodeSubtitleBytes(Uint8List.fromList(utf8.encode('Привіт'))), 'Привіт');
      expect(decodeSubtitleBytes(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('Привіт')])), 'Привіт');
    });

    test('UTF-16 LE and BE with BOM', () {
      final units = 'Ґанок'.codeUnits;
      expect(
        decodeSubtitleBytes(
          Uint8List.fromList([
            0xFF,
            0xFE,
            for (final u in units) ...[u & 0xFF, u >> 8],
          ]),
        ),
        'Ґанок',
      );
      expect(
        decodeSubtitleBytes(
          Uint8List.fromList([
            0xFE,
            0xFF,
            for (final u in units) ...[u >> 8, u & 0xFF],
          ]),
        ),
        'Ґанок',
      );
    });

    test('not UTF-8: Windows-1251', () {
      // "Їжак ґанок, № 1" in Windows-1251.
      final bytes = [0xAF, 0xE6, 0xE0, 0xEA, 0x20, 0xB4, 0xE0, 0xED, 0xEE, 0xEA, 0x2C, 0x20, 0xB9, 0x20, 0x31];
      expect(decodeSubtitleBytes(Uint8List.fromList(bytes)), 'Їжак ґанок, № 1');
    });
  });
}
