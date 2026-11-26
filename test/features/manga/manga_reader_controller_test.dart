import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/manga/domain/manga_reader_state.dart';
import 'package:strumok/features/manga/presentation/manga_reader_controller.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_manga.dart';
import '../../helpers/test_overrides.dart';

void main() {
  late ProviderContainer c;
  late MangaReaderController controller;
  final provider = mangaReaderControllerProvider('alpha', 'm1');

  MangaReaderState state() => c.read(provider);
  CollectionItem? stored() => c.read(collectionItemsProvider).value?[collectionItemKey('alpha', 'm1')];

  Future<void> setUpWith(List<FakeMediaItem> chapters, {CollectionItem? item}) async {
    final supplier = FakeSupplier('alpha', details: {'m1': mangaDetails(chapters)});
    c = ProviderContainer(
      overrides: await testOverrides(bundle: SupplierBundleReady(FakeBundle([supplier]), bundleInfo('4.0.0'))),
    );
    addTearDown(c.dispose);
    addTearDown(pumpEventQueue);
    // Keeps the auto-dispose controller alive, as the reader page does.
    c.listen(provider, (_, _) {});
    controller = c.read(provider.notifier);
    await c.read(collectionItemsProvider.future);
    if (item != null) await c.read(collectionItemsProvider.notifier).save(item);
  }

  const inCollection = CollectionItem(
    id: 'm1',
    supplier: 'alpha',
    title: 'Old title',
    image: '',
    mediaType: MediaType.manga,
    currentItem: 1,
    currentSourceName: 'EN',
    positions: {1: MediaItemPosition(position: 2, length: 4)},
    status: CollectionStatus.latter,
  );

  test('resumes currentItem at its remembered page with the remembered translation', () async {
    await setUpWith([chapter(0), chapter(1), chapter(2)], item: inCollection);
    await controller.open();

    final s = state();
    expect(s.ready, isTrue);
    expect(s.title, 'Manga');
    expect(s.itemIndex, 1);
    expect(s.source!.description, 'EN');
    expect(s.pages, pageUrls('EN', 1, 4));
    expect(s.page, 2);
    expect(s.generation, 1);
    expect(stored()!.title, 'Manga', reason: 'refreshed from the supplier');
    expect(stored()!.status, CollectionStatus.latter, reason: 'no page read yet');
  });

  test('without a collection item: first chapter, first translation, page 0, nothing saved', () async {
    await setUpWith([chapter(0), chapter(1)]);
    await controller.open();

    expect(state().itemIndex, 0);
    expect(state().source!.description, 'UA');
    expect(state().source!.headers, {'referer': 'https://manga.example'});
    expect(state().page, 0);
    expect(stored(), isNull);
  });

  test('a page change saves progress and adds the title to the collection', () async {
    await setUpWith([chapter(0), chapter(1)]);
    await controller.open(item: 1);
    await controller.setPage(3);

    final item = stored()!;
    expect(item.mediaType, MediaType.manga);
    expect(item.title, 'Manga');
    expect(item.status, CollectionStatus.inProgress);
    expect(item.currentItem, 1);
    expect(item.positions[1], const MediaItemPosition(position: 3, length: 5));

    final lastSeen = item.lastSeen;
    await controller.setPage(3);
    expect(stored()!.lastSeen, lastSeen, reason: 'same page: no write');
  });

  test('an explicitly picked finished chapter starts over', () async {
    await setUpWith([
      chapter(0),
      chapter(1),
    ], item: inCollection.copyWith(positions: {0: const MediaItemPosition(position: 4, length: 5)}));
    await controller.open(item: 0);
    expect(state().page, 0);
  });

  test('next chapter opens at the start and records the finished one', () async {
    await setUpWith([chapter(0), chapter(1)]);
    await controller.open();
    await controller.setPage(4);
    await controller.nextChapter();

    expect(state().itemIndex, 1);
    expect(state().page, 0);
    expect(state().generation, 2);
    expect(stored()!.currentItem, 1);
    expect(stored()!.positions[0], const MediaItemPosition(position: 4, length: 5));

    await controller.nextChapter();
    expect(state().itemIndex, 1, reason: 'no chapter after the last');
  });

  test('previous chapter opens at its last page', () async {
    await setUpWith([chapter(0), chapter(1)]);
    await controller.open(item: 1);
    await controller.previousChapter();

    expect(state().itemIndex, 0);
    expect(state().page, 4);
  });

  test('changing the translation keeps the page and is remembered', () async {
    await setUpWith([chapter(0)], item: inCollection.copyWith(currentItem: 0, currentSourceName: 'UA'));
    await controller.open();
    await controller.setPage(4);
    await controller.selectSource(1);

    expect(state().source!.description, 'EN');
    expect(state().page, 3, reason: 'clamped to the 4 pages of EN');
    expect(stored()!.currentSourceName, 'EN');
  });

  test('refreshing reloads translations and pages, keeping the translation and page', () async {
    final item = RefreshingMediaItem(
      0,
      'Chapter 1',
      sourceList: [
        FakeMangaSource('UA', pages: pageUrls('UA', 0, 5)),
        FakeMangaSource('EN', pages: pageUrls('EN', 0, 4)),
      ],
      refreshed: [
        FakeMangaSource('UA', pages: pageUrls('UA-new', 0, 5)),
        FakeMangaSource('EN', pages: pageUrls('EN-new', 0, 3)),
      ],
    );
    await setUpWith([item]);
    await controller.open();
    await controller.selectSource(1);
    await controller.setPage(3);

    await controller.refreshSources();
    expect(item.refreshes, 1);
    expect(state().source!.description, 'EN');
    expect(state().pages, pageUrls('EN-new', 0, 3));
    expect(state().page, 2, reason: 'clamped to the refreshed page count');
    expect(stored()!.positions[0], const MediaItemPosition(position: 3, length: 4), reason: 'saved before reloading');
  });

  test('chapter without pages fails; retry reloads', () async {
    var attempt = 0;
    final source = FakeMangaSource(
      'UA',
      load: () async => ++attempt == 1 ? throw Exception('offline') : pageUrls('UA', 0, 2),
    );
    await setUpWith([
      chapter(0, sources: [source]),
    ]);
    await controller.open();
    expect(state().failure, MangaReaderFailure.loadFailed);

    await controller.retry();
    expect(state().failure, isNull);
    expect(state().pages, hasLength(2));
  });

  test('no manga sources or no chapters report no pages', () async {
    await setUpWith([chapter(0, sources: const [])]);
    await controller.open();
    expect(state().failure, MangaReaderFailure.noPages);

    await setUpWith(const []);
    await controller.open();
    expect(state().failure, MangaReaderFailure.noPages);
  });

  test('a newer load wins over a slower older one', () async {
    final slow = Completer<List<String>>();
    await setUpWith([
      chapter(0, sources: [FakeMangaSource('UA', load: () => slow.future)]),
      chapter(1),
    ]);
    final first = controller.open(item: 0);
    await pumpEventQueue();
    await controller.selectItem(1);
    slow.complete(pageUrls('UA', 0, 9));
    await first;

    expect(state().itemIndex, 1);
    expect(state().pages, pageUrls('UA', 1, 5));
  });
}
