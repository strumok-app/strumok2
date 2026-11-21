@TestOn('linux || windows')
library;

import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:content_suppliers_rust/bundle.dart';
import 'package:test/test.dart';

// Requires `cargo build --release` in rust/; skipped otherwise.
void main() {
  final dir = '${Directory.current.path}/rust/target/release';
  final bundle = RustContentSuppliersBundle(directory: dir, libName: 'content_suppliers_rust');
  final libExists = File(bundle.libPath).existsSync();

  group('dummy bundle', skip: libExists ? null : 'dummy lib not built: ${bundle.libPath}', () {
    late ContentSupplier dummy;

    setUpAll(() async {
      await bundle.load();
      dummy = bundle.suppliers.singleWhere((s) => s.name == 'dummy');
    });

    tearDownAll(bundle.unload);

    test('sync metadata', () {
      expect(dummy.channels, {'dummy_channels'});
      expect(dummy.defaultChannels, {'dummy_channels'});
      expect(dummy.supportedTypes, {ContentType.movie, ContentType.anime});
      expect(dummy.supportedLanguages, {ContentLanguage.en, ContentLanguage.uk});
    });

    test('search and channel', () async {
      final found = await dummy.search('query');
      expect(found.single.id, 'query');
      expect(found.single.supplier, 'dummy');

      final channel = await dummy.loadChannel('dummy_channels', page: 2);
      expect(channel.single.id, 'dummy_channels 2');
    });

    test('lazy media items, sources and manga pages', () async {
      final details = (await dummy.detailsById('id'))!;
      expect(details.mediaType, MediaType.video);
      expect(details.similar.single.id, 'dummy_similar');

      final item = (await details.mediaItems).single;
      expect(item.number, 0);
      expect(item.section, '1,2,3');

      final sources = await item.sources;
      expect(sources.map((s) => s.kind), [FileKind.video, FileKind.subtitle, FileKind.manga]);
      expect(sources.map((s) => s.language), [ContentLanguage.en, ContentLanguage.uk, null]);
      expect(sources.first.headers, {'User-Agent': 'dummy'});
      expect((sources.first as VideoMediaItemSource).hlsProxy, isFalse);
      expect(await (sources.last as MangaMediaItemSource).allPages, ['http://page1', 'http://page2']);
    });

    test('eager sources', () async {
      final details = (await dummy.detailsById('eager_sources'))!;
      final source = (await (await details.mediaItems).single.sources).single as VideoMediaItemSource;
      expect(await source.link, Uri.parse('http://paga'));
    });

    test('lazy manga pages', () async {
      final details = (await dummy.detailsById('async_manga'))!;
      final source = (await (await details.mediaItems).single.sources).single as MangaMediaItemSource;
      expect(await source.allPages, ['http://async_manga_async_manga']);
    });
  });

  test('missing lib throws ContentSuppliersException', () {
    final missing = RustContentSuppliersBundle(directory: '/nonexistent', libName: 'nope');
    expect(missing.load, throwsA(isA<ContentSuppliersException>()));
  });
}
