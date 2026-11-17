import 'package:flutter/foundation.dart';

/// Spec-09 key `manga_reader_mode` (values by `.name`).
enum MangaReaderMode {
  /// Vertical continuous scroll.
  longStrip,

  /// One page at a time, turned vertically.
  vertical,
  leftToRight,
  rightToLeft;

  bool get paged => this != longStrip;

  bool get horizontal => this == leftToRight || this == rightToLeft;
}

/// Spec-09 key `manga_reader_background` (values by `.name`).
enum MangaReaderBackground { dark, light }

/// Persisted reader settings (spec-07).
@immutable
final class MangaReaderPreferences {
  final MangaReaderMode mode;
  final MangaReaderBackground background;

  /// Trim uniform white/black page borders.
  final bool autoCrop;

  const MangaReaderPreferences({
    this.mode = MangaReaderMode.longStrip,
    this.background = MangaReaderBackground.dark,
    this.autoCrop = true,
  });

  MangaReaderPreferences copyWith({MangaReaderMode? mode, MangaReaderBackground? background, bool? autoCrop}) =>
      MangaReaderPreferences(
        mode: mode ?? this.mode,
        background: background ?? this.background,
        autoCrop: autoCrop ?? this.autoCrop,
      );

  @override
  bool operator ==(Object other) =>
      other is MangaReaderPreferences &&
      other.mode == mode &&
      other.background == background &&
      other.autoCrop == autoCrop;

  @override
  int get hashCode => Object.hash(mode, background, autoCrop);
}
