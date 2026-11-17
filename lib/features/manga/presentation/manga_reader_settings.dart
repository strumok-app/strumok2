import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/storage/app_preferences.dart';
import '../domain/manga_reader_preferences.dart';

part 'manga_reader_settings.g.dart';

/// Persisted reader settings (spec-09 keys, enums stored by `.name`).
@Riverpod(keepAlive: true)
class MangaReaderSettings extends _$MangaReaderSettings {
  AppPreferences get _prefs => ref.read(appPreferencesProvider);

  @override
  MangaReaderPreferences build() {
    final prefs = _prefs;
    return MangaReaderPreferences(
      mode:
          MangaReaderMode.values.asNameMap()[prefs.getString(AppPreferences.mangaReaderMode)] ??
          MangaReaderMode.longStrip,
      background:
          MangaReaderBackground.values.asNameMap()[prefs.getString(AppPreferences.mangaReaderBackground)] ??
          MangaReaderBackground.dark,
      autoCrop: prefs.getBool(AppPreferences.mangaReaderAutoCrop) ?? true,
    );
  }

  Future<void> setMode(MangaReaderMode value) async {
    state = state.copyWith(mode: value);
    await _prefs.setString(AppPreferences.mangaReaderMode, value.name);
  }

  Future<void> setBackground(MangaReaderBackground value) async {
    state = state.copyWith(background: value);
    await _prefs.setString(AppPreferences.mangaReaderBackground, value.name);
  }

  Future<void> setAutoCrop(bool value) async {
    state = state.copyWith(autoCrop: value);
    await _prefs.setBool(AppPreferences.mangaReaderAutoCrop, value);
  }
}

String readerModeLabel(AppLocalizations l10n, MangaReaderMode value) => switch (value) {
  MangaReaderMode.longStrip => l10n.readerModeLongStrip,
  MangaReaderMode.vertical => l10n.readerModeVertical,
  MangaReaderMode.leftToRight => l10n.readerModeLeftToRight,
  MangaReaderMode.rightToLeft => l10n.readerModeRightToLeft,
};

String readerBackgroundLabel(AppLocalizations l10n, MangaReaderBackground value) => switch (value) {
  MangaReaderBackground.dark => l10n.readerBackgroundDark,
  MangaReaderBackground.light => l10n.readerBackgroundLight,
};
