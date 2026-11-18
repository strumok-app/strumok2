import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../collection/domain/collection_item.dart';
import '../../collection/domain/progress.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../details/presentation/details_providers.dart';
import '../domain/manga_reader_state.dart';

part 'manga_reader_controller.g.dart';

final _log = Logger('MangaReaderController');

/// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
/// page in the collection (spec-03 §3.3).
@riverpod
class MangaReaderController extends _$MangaReaderController {
  /// Incremented by every load; async steps of an older load stop when it changed.
  int _token = 0;
  int? _requestedItem;
  ContentDetails? _details;

  /// Chapter/translation picked for a title that is not in the collection (never persisted).
  CollectionItem? _untracked;

  @override
  MangaReaderState build(String supplier, String id) => MangaReaderState(supplier: supplier, id: id);

  /// [item] = number of a chapter picked explicitly; null resumes `currentItem` of the collection. Numbers are the
  /// collection keys; offline content lists only downloaded chapters, so they differ from list indexes there.
  Future<void> open({int? item}) async {
    final token = ++_token;
    _requestedItem = item;
    state = MangaReaderState(supplier: supplier, id: id, generation: state.generation);
    try {
      final details = await ref.read(contentDetailsProvider(supplier, id).future);
      final items = await ref.read(mediaItemsProvider(supplier, id).future);
      final collection = await ref.read(collectionItemsProvider.future);
      if (!_isCurrent(token)) return;

      _details = details;
      _untracked = null;
      state = state.copyWith(title: details.title, items: items);
      if (items.isEmpty) {
        state = state.copyWith(loading: false, failure: MangaReaderFailure.noPages);
        return;
      }
      final stored = collection[collectionItemKey(supplier, id)];
      final index = itemIndexOfNumber(items, item ?? stored?.currentItem ?? 0) ?? 0;
      await _openItem(token, index, restartCompleted: item != null);
    } catch (e, st) {
      _fail(token, e, st);
    }
  }

  /// Chapter picked from the list: a finished one starts over.
  Future<void> selectItem(int index) async {
    if (index < 0 || index >= state.items.length) return;
    await _openItem(++_token, index, restartCompleted: true);
  }

  Future<void> nextChapter() async {
    if (!state.hasNext) return;
    await _openItem(++_token, state.itemIndex + 1);
  }

  /// Opens the previous chapter at its last page, continuing backwards.
  Future<void> previousChapter() async {
    if (!state.hasPrevious) return;
    await _openItem(++_token, state.itemIndex - 1, fromEnd: true);
  }

  /// Switches the translation, staying on the same page number.
  Future<void> selectSource(int index) async {
    final current = state;
    if (index < 0 || index >= current.sources.length || (index == current.sourceIndex && current.ready)) return;
    final token = ++_token;
    state = current.copyWith(sourceIndex: index, pages: const [], loading: true, clearFailure: true);
    await _updateItem((item) => item.copyWith(currentSourceName: current.sources[index].description));
    await _loadPages(token, (count) => current.page.clamp(0, count - 1));
  }

  /// The view shows [page]; persisted when it changed (spec-03 §3.3).
  Future<void> setPage(int page) async {
    if (!state.ready || page == state.page || page < 0 || page >= state.pages.length) return;
    state = state.copyWith(page: page);
    await _saveProgress();
  }

  Future<void> retry() async {
    final current = state;
    if (current.items.isEmpty) return open(item: _requestedItem);
    if (current.sources.isEmpty) return _openItem(++_token, current.itemIndex);
    final token = ++_token;
    state = current.copyWith(loading: true, clearFailure: true);
    await _loadPages(token, (count) => current.page.clamp(0, count - 1));
  }

  bool _isCurrent(int token) => ref.mounted && token == _token;

  Future<void> _openItem(int token, int index, {bool fromEnd = false, bool restartCompleted = false}) async {
    // Leaving a chapter records where it was left, e.g. the last page of a one-page chapter.
    if (state.ready) await _saveProgress();
    if (!_isCurrent(token)) return;
    state = state.copyWith(
      itemIndex: index,
      sources: const [],
      sourceIndex: 0,
      pages: const [],
      page: 0,
      loading: true,
      clearFailure: true,
    );
    final number = state.items[index].number;
    await _updateItem((item) => item.copyWith(currentItem: number));
    try {
      final all = await state.items[index].sources;
      if (!_isCurrent(token)) return;
      final sources = all.whereType<MangaMediaItemSource>().toList();
      if (sources.isEmpty) {
        state = state.copyWith(loading: false, failure: MangaReaderFailure.noPages);
        return;
      }
      state = state.copyWith(sources: sources, sourceIndex: chooseMangaSource(sources, _latest?.currentSourceName));
      final remembered = _latest?.positions[number];
      await _loadPages(
        token,
        (count) => mangaStartPage(count, remembered: remembered, fromEnd: fromEnd, restartCompleted: restartCompleted),
      );
    } catch (e, st) {
      _fail(token, e, st);
    }
  }

  Future<void> _loadPages(int token, int Function(int count) startPage) async {
    try {
      final pages = await state.source!.allPages;
      if (!_isCurrent(token)) return;
      if (pages.isEmpty) {
        state = state.copyWith(loading: false, failure: MangaReaderFailure.noPages);
        return;
      }
      state = state.copyWith(
        pages: pages,
        page: startPage(pages.length),
        generation: state.generation + 1,
        loading: false,
      );
    } catch (e, st) {
      _fail(token, e, st);
    }
  }

  void _fail(int token, Object error, StackTrace stackTrace) {
    _log.warning('Reader load failed', error, stackTrace);
    if (_isCurrent(token)) state = state.copyWith(loading: false, failure: MangaReaderFailure.loadFailed);
  }

  /// Collection item with the latest synced data (or the untracked one), refreshed with this session's title/image.
  CollectionItem? get _latest {
    final details = _details;
    if (details == null || !ref.mounted) return null;
    final stored = ref.read(collectionItemsProvider).value?[collectionItemKey(supplier, id)];
    return stored?.copyWith(title: details.title, image: details.image) ??
        (_untracked ??= CollectionItem(
          id: id,
          supplier: supplier,
          title: details.title,
          image: details.image,
          mediaType: MediaType.manga,
        ));
  }

  /// Applies [change]; persists only items that are in the collection (saving `status == none` deletes).
  Future<void> _updateItem(CollectionItem Function(CollectionItem item) change) async {
    final latest = _latest;
    if (latest == null) return;
    final updated = change(latest);
    if (updated.status == CollectionStatus.none) {
      _untracked = updated;
    } else {
      await ref.read(collectionItemsProvider.notifier).save(updated);
    }
  }

  /// Reading adds the title to the collection as in progress (as watching does, spec-03 §3.3).
  // SPEC: the page the chapter opens at is not saved; the first page change (or leaving the chapter) is.
  Future<void> _saveProgress() async {
    final latest = _latest;
    final current = state;
    if (latest == null || !current.ready) return;
    final updated = updateMangaProgress(
      latest,
      itemIndex: current.item!.number,
      page: current.page,
      pageCount: current.pages.length,
    );
    if (updated == null) return;
    await ref.read(collectionItemsProvider.notifier).save(updated);
  }
}
