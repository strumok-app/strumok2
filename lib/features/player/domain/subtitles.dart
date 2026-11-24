import 'package:flutter/foundation.dart';

@immutable
final class SubtitleCue {
  final Duration start;
  final Duration end;

  /// Plain text; lines separated by `\n`.
  final String text;

  const SubtitleCue(this.start, this.end, this.text);

  @override
  bool operator ==(Object other) =>
      other is SubtitleCue && other.start == start && other.end == end && other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'SubtitleCue($start, $end, $text)';
}

/// Parsed external subtitles, cues sorted by start.
final class SubtitleTrack {
  final List<SubtitleCue> cues;

  /// Longest cue, bounds the backwards scan in [linesAt].
  final Duration _maxLength;

  SubtitleTrack(List<SubtitleCue> cues)
    : cues = List.unmodifiable([...cues]..sort((a, b) => a.start.compareTo(b.start))),
      _maxLength = cues.fold(Duration.zero, (max, c) => c.end - c.start > max ? c.end - c.start : max);

  /// Text lines of the cues shown at [position]; a positive [offset] shows subtitles later.
  List<String> linesAt(Duration position, {Duration offset = Duration.zero}) {
    final at = position - offset;
    // First cue starting after `at`.
    var low = 0, high = cues.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (cues[mid].start <= at) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final lines = <String>[];
    for (var i = low - 1; i >= 0 && at - cues[i].start <= _maxLength; i--) {
      if (cues[i].end > at) lines.insertAll(0, cues[i].text.split('\n'));
    }
    return lines;
  }
}

/// WebVTT, SRT or ASS, detected by content; malformed cues are skipped.
SubtitleTrack parseSubtitles(String text) {
  final normalized = text.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return _assHeader.hasMatch(normalized) ? _parseAss(normalized) : _parseVttOrSrt(normalized);
}

SubtitleTrack _parseVttOrSrt(String text) {
  final cues = <SubtitleCue>[];
  for (final block in text.split(RegExp(r'\n[ \t]*\n'))) {
    final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final timing = lines.indexWhere((l) => l.contains('-->'));
    if (timing < 0) continue;
    final match = _timing.firstMatch(lines[timing]);
    if (match == null) continue;
    final start = _parseTime(match.group(1)!), end = _parseTime(match.group(2)!);
    if (start == null || end == null || end <= start) continue;
    final body = sanitizeCueText(lines.skip(timing + 1).join('\n'));
    if (body.isNotEmpty) cues.add(SubtitleCue(start, end, body));
  }
  return SubtitleTrack(cues);
}

final _assHeader = RegExp(r'^(?:\s|;[^\n]*\n)*\[(?:Script Info|Events)\]', caseSensitive: false);

SubtitleTrack _parseAss(String text) {
  final cues = <SubtitleCue>[];
  var inEvents = false;
  var fieldCount = 0, startIndex = -1, endIndex = -1;
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('[')) {
      inEvents = line.toLowerCase() == '[events]';
      fieldCount = 0;
      continue;
    }
    if (!inEvents) continue;
    final colon = line.indexOf(':');
    if (colon < 0) continue;
    final kind = line.substring(0, colon).trimRight().toLowerCase();
    final value = line.substring(colon + 1);
    if (kind == 'format') {
      final fields = value.split(',').map((field) => field.trim().toLowerCase()).toList();
      startIndex = fields.indexOf('start');
      endIndex = fields.indexOf('end');
      fieldCount = startIndex >= 0 && endIndex >= 0 && fields.last == 'text' ? fields.length : 0;
    } else if (kind == 'dialogue' && fieldCount > 0) {
      final fields = _splitAssDialogue(value, fieldCount);
      if (fields == null) continue;
      final start = _parseTime(fields[startIndex].trim()), end = _parseTime(fields[endIndex].trim());
      if (start == null || end == null || end <= start) continue;
      final body = _plainAssText(fields.last);
      if (body.isNotEmpty) cues.add(SubtitleCue(start, end, body));
    }
  }
  return SubtitleTrack(cues);
}

List<String>? _splitAssDialogue(String value, int fieldCount) {
  final fields = <String>[];
  var from = 0;
  // Text is the last field and can contain commas.
  for (var i = 1; i < fieldCount; i++) {
    final comma = value.indexOf(',', from);
    if (comma < 0) return null;
    fields.add(value.substring(from, comma));
    from = comma + 1;
  }
  return fields..add(value.substring(from));
}

final _assTextToken = RegExp(r'\{[^}]*\}|\\[Nnh]');
final _assDrawingMode = RegExp(r'\\p\s*0*(\d+)');

String _plainAssText(String text) {
  final body = StringBuffer();
  var drawing = false;
  var from = 0;
  for (final token in _assTextToken.allMatches(text)) {
    if (!drawing) body.write(text.substring(from, token.start));
    from = token.end;
    final value = token.group(0)!;
    if (value.startsWith('{')) {
      for (final mode in _assDrawingMode.allMatches(value)) {
        drawing = mode.group(1) != '0';
      }
    } else if (!drawing) {
      body.write(switch (value) {
        r'\N' => '\n',
        r'\h' => '\u00A0',
        _ => ' ',
      });
    }
  }
  if (!drawing) body.write(text.substring(from));
  return _cleanCueLines(body.toString());
}

final _timing = RegExp(r'^\s*(\S+)\s+-->\s+(\S+)');
final _time = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{1,2})(?:[.,](\d{1,3}))?$');

Duration? _parseTime(String value) {
  final m = _time.firstMatch(value);
  if (m == null) return null;
  final fraction = (m.group(4) ?? '0').padRight(3, '0');
  return Duration(
    hours: int.parse(m.group(1) ?? '0'),
    minutes: int.parse(m.group(2)!),
    seconds: int.parse(m.group(3)!),
    milliseconds: int.parse(fraction),
  );
}

final _tags = RegExp(r'<[^>]*>');
final _assOverrides = RegExp(r'\{\\[^}]*\}');
final _entities = {'&amp;': '&', '&lt;': '<', '&gt;': '>', '&nbsp;': ' ', '&quot;': '"', '&#39;': "'", '&apos;': "'"};
final _entity = RegExp(r'&(amp|lt|gt|nbsp|quot|apos|#39);');

/// Strips markup (HTML-like and VTT tags, ASS overrides like `{\an8}`) and decodes common entities.
String sanitizeCueText(String text) => _cleanCueLines(
  text
      .replaceAll(_tags, '')
      .replaceAll(_assOverrides, '')
      .replaceAllMapped(_entity, (m) => _entities[m.group(0)]!)
      .replaceAll(r'\N', '\n'),
);

String _cleanCueLines(String text) => text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
