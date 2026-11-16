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

/// WebVTT or SRT, detected by content; malformed cues are skipped.
SubtitleTrack parseSubtitles(String text) {
  final normalized = text.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final cues = <SubtitleCue>[];
  for (final block in normalized.split(RegExp(r'\n[ \t]*\n'))) {
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
String sanitizeCueText(String text) => text
    .replaceAll(_tags, '')
    .replaceAll(_assOverrides, '')
    .replaceAllMapped(_entity, (m) => _entities[m.group(0)]!)
    .replaceAll(r'\N', '\n')
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .join('\n');
