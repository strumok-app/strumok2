/// Which of an item's sources to download when a batch was queued with source names picked on another item: a
/// group's sources differ from item to item (another scanlation group from chapter 101, servers flickering between
/// episodes).
///
/// [preferred] (the user's choice, highest priority first) and then [previous] (what the nearest earlier item was
/// downloaded with, so a switch sticks) are tried by exact name; otherwise the most similar name wins (see
/// [_score]), ties going to the higher-priority reference and then to the earlier source. Returns the index in
/// [names], or null when nothing matches or looks similar.
int? chooseDownloadSource(
  List<String> names, {
  required List<String> preferred,
  List<String> previous = const [],
  bool strictTags = false,
}) {
  final references = {...preferred, ...previous}.toList();
  for (final reference in references) {
    final index = names.indexOf(reference);
    if (index >= 0) return index;
  }

  final parsed = [for (final name in names) _SourceName.parse(name)];
  int? best;
  var bestScore = 0;
  for (final reference in references.map(_SourceName.parse)) {
    for (final (index, candidate) in parsed.indexed) {
      final score = _score(candidate, reference, strictTags: strictTags);
      if (score > bestScore) (best, bestScore) = (index, score);
    }
  }
  return best;
}

const _tagWeight = 4;

/// Shared `[tags]` (language on MangaDex, provider on TMDB: `[en] Group`, `[VidFast] Server 1`) weigh
/// [_tagWeight] words each; 0 = not similar. With `strictTags` a candidate must share a tag with a tagged reference
/// (manga: never switch the translation language).
int _score(_SourceName candidate, _SourceName reference, {required bool strictTags}) {
  final tags = candidate.tags.intersection(reference.tags).length;
  if (strictTags && reference.tags.isNotEmpty && tags == 0) return 0;
  return tags * _tagWeight + candidate.words.intersection(reference.words).length;
}

final class _SourceName {
  final Set<String> tags;
  final Set<String> words;

  const _SourceName(this.tags, this.words);

  static final _tag = RegExp(r'\[([^\]]*)\]');
  static final _separator = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  factory _SourceName.parse(String name) {
    final lower = name.toLowerCase();
    return _SourceName({
      for (final match in _tag.allMatches(lower))
        if (match[1]!.trim() case final tag when tag.isNotEmpty) tag,
    }, lower.replaceAll(_tag, ' ').split(_separator).where((w) => w.isNotEmpty).toSet());
  }
}
