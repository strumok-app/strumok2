import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/manga/domain/manga_reader_preferences.dart';
import 'package:strumok/features/manga/domain/manga_reader_state.dart';
import 'package:strumok/features/manga/presentation/manga_reader_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../helpers/fake_manga.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('mangaStartPage', () {
    test('starts at 0 without a remembered page', () {
      expect(mangaStartPage(10), 0);
      expect(mangaStartPage(0, remembered: const MediaItemPosition(position: 3)), 0);
    });

    test('resumes the remembered page, clamped to the chapter', () {
      expect(mangaStartPage(10, remembered: const MediaItemPosition(position: 4, length: 10)), 4);
      expect(mangaStartPage(5, remembered: const MediaItemPosition(position: 8, length: 10)), 4);
    });

    test('fromEnd opens the last page', () {
      expect(mangaStartPage(7, remembered: const MediaItemPosition(position: 2, length: 7), fromEnd: true), 6);
    });

    test('a finished chapter starts over only when picked explicitly', () {
      const finished = MediaItemPosition(position: 9, length: 10);
      expect(mangaStartPage(10, remembered: finished), 9);
      expect(mangaStartPage(10, remembered: finished, restartCompleted: true), 0);
      expect(
        mangaStartPage(10, remembered: const MediaItemPosition(position: 5, length: 10), restartCompleted: true),
        5,
      );
    });
  });

  test('chooseMangaSource picks the remembered translation, else the first', () {
    final sources = [FakeMangaSource('UA'), FakeMangaSource('EN')];
    expect(chooseMangaSource(sources, 'EN'), 1);
    expect(chooseMangaSource(sources, 'JP'), 0);
    expect(chooseMangaSource(sources, null), 0);
  });

  test('preloadPages covers ±2 within the chapter', () {
    expect(preloadPages(0, 10).toList(), [0, 1, 2]);
    expect(preloadPages(5, 10).toList(), [3, 4, 5, 6, 7]);
    expect(preloadPages(9, 10).toList(), [7, 8, 9]);
    expect(preloadPages(0, 1).toList(), [0]);
  });

  group('reader settings', () {
    Future<ProviderContainer> container([Map<String, Object> values = const {}]) async {
      final c = ProviderContainer(overrides: await testOverrides(prefs: await createTestPreferences(values)));
      addTearDown(c.dispose);
      return c;
    }

    test('defaults: long strip, dark, auto-crop on', () async {
      final c = await container();
      expect(c.read(mangaReaderSettingsProvider), const MangaReaderPreferences());
      expect(const MangaReaderPreferences().mode, MangaReaderMode.longStrip);
      expect(const MangaReaderPreferences().background, MangaReaderBackground.dark);
      expect(const MangaReaderPreferences().autoCrop, isTrue);
    });

    test('reads and writes the spec-09 keys by enum name', () async {
      final c = await container({
        AppPreferences.mangaReaderMode: 'rightToLeft',
        AppPreferences.mangaReaderBackground: 'light',
        AppPreferences.mangaReaderAutoCrop: false,
      });
      expect(
        c.read(mangaReaderSettingsProvider),
        const MangaReaderPreferences(
          mode: MangaReaderMode.rightToLeft,
          background: MangaReaderBackground.light,
          autoCrop: false,
        ),
      );

      final notifier = c.read(mangaReaderSettingsProvider.notifier);
      await notifier.setMode(MangaReaderMode.vertical);
      await notifier.setBackground(MangaReaderBackground.dark);
      await notifier.setAutoCrop(true);
      final prefs = c.read(appPreferencesProvider);
      expect(prefs.getString(AppPreferences.mangaReaderMode), 'vertical');
      expect(prefs.getString(AppPreferences.mangaReaderBackground), 'dark');
      expect(prefs.getBool(AppPreferences.mangaReaderAutoCrop), isTrue);
    });

    test('unknown stored values fall back to defaults', () async {
      final c = await container({AppPreferences.mangaReaderMode: 'webtoon'});
      expect(c.read(mangaReaderSettingsProvider).mode, MangaReaderMode.longStrip);
    });
  });
}
