import 'package:content_suppliers_api/content_suppliers_api.dart';

import 'test_overrides.dart';

class FakeMangaSource extends MangaMediaItemSource {
  @override
  final String description;
  @override
  final Map<String, String>? headers;
  @override
  final ContentLanguage? language;
  final Future<List<String>> Function() loadPages;
  var loads = 0;

  FakeMangaSource(
    this.description, {
    List<String>? pages,
    Future<List<String>> Function()? load,
    this.headers,
    this.language,
  }) : loadPages = load ?? (() async => pages ?? const []);

  @override
  Future<List<String>> get allPages {
    loads++;
    return loadPages();
  }
}

/// Remote page URLs `https://img.example/<source>/<chapter>/<page>.jpg`.
List<String> pageUrls(String source, int chapter, int count) => [
  for (var i = 0; i < count; i++) 'https://img.example/$source/$chapter/$i.jpg',
];

/// Chapter [n] with translations UA (5 pages) and EN (4 pages) unless [sources] is given.
FakeMediaItem chapter(int n, {List<MangaMediaItemSource>? sources, int pages = 5}) => FakeMediaItem(
  n,
  'Chapter ${n + 1}',
  sourceList:
      sources ??
      [
        FakeMangaSource('UA', pages: pageUrls('UA', n, pages), headers: const {'referer': 'https://manga.example'}),
        FakeMangaSource('EN', pages: pageUrls('EN', n, pages - 1)),
      ],
);

FakeDetails mangaDetails(List<FakeMediaItem> chapters, {String id = 'm1'}) =>
    FakeDetails('alpha', id, title: 'Manga', mediaType: MediaType.manga, loadItems: () async => chapters);
