import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';

import '../../collection/domain/collection_item.dart';

enum MangaReaderFailure { loadFailed, noPages }

/// Index of the translation named [preferred] (`currentSourceName` = description), else the first one.
int chooseMangaSource(List<MangaMediaItemSource> sources, String? preferred) =>
    max(0, sources.indexWhere((s) => s.description == preferred));

/// Page to open a chapter at: the remembered page (clamped to the chapter), the last page with [fromEnd]
/// (stepping back from the next chapter). A finished chapter starts over when [restartCompleted]
/// (picked explicitly from the chapter list).
// SPEC: spec-07 has no resume rule; decided without the legacy app (resume = remembered page, clamped).
int mangaStartPage(
  int pageCount, {
  MediaItemPosition? remembered,
  bool fromEnd = false,
  bool restartCompleted = false,
}) {
  if (pageCount <= 0) return 0;
  if (fromEnd) return pageCount - 1;
  if (remembered == null) return 0;
  final completed = remembered.length > 0 && remembered.position >= remembered.length - 1;
  if (restartCompleted && completed) return 0;
  return remembered.position.clamp(0, pageCount - 1);
}

/// Page indexes to keep loaded around [page] (spec-07: ±2).
Iterable<int> preloadPages(int page, int pageCount, {int radius = 2}) sync* {
  for (var i = max(0, page - radius); i <= min(pageCount - 1, page + radius); i++) {
    yield i;
  }
}

/// What the reader shows. [generation] changes whenever a new page list is loaded (chapter or translation),
/// so views reposition to [page] instead of keeping their own scroll position.
final class MangaReaderState {
  final String supplier;
  final String id;
  final String title;
  final List<ContentMediaItem> items;
  final int itemIndex;
  final List<MangaMediaItemSource> sources;
  final int sourceIndex;
  final List<String> pages;
  final int page;
  final int generation;
  final bool loading;
  final MangaReaderFailure? failure;

  const MangaReaderState({
    required this.supplier,
    required this.id,
    this.title = '',
    this.items = const [],
    this.itemIndex = 0,
    this.sources = const [],
    this.sourceIndex = 0,
    this.pages = const [],
    this.page = 0,
    this.generation = 0,
    this.loading = true,
    this.failure,
  });

  ContentMediaItem? get item => itemIndex < items.length ? items[itemIndex] : null;
  MangaMediaItemSource? get source => sourceIndex < sources.length ? sources[sourceIndex] : null;
  bool get hasPrevious => itemIndex > 0;
  bool get hasNext => itemIndex + 1 < items.length;
  bool get ready => !loading && failure == null && pages.isNotEmpty;

  MangaReaderState copyWith({
    String? title,
    List<ContentMediaItem>? items,
    int? itemIndex,
    List<MangaMediaItemSource>? sources,
    int? sourceIndex,
    List<String>? pages,
    int? page,
    int? generation,
    bool? loading,
    MangaReaderFailure? failure,
    bool clearFailure = false,
  }) => MangaReaderState(
    supplier: supplier,
    id: id,
    title: title ?? this.title,
    items: items ?? this.items,
    itemIndex: itemIndex ?? this.itemIndex,
    sources: sources ?? this.sources,
    sourceIndex: sourceIndex ?? this.sourceIndex,
    pages: pages ?? this.pages,
    page: page ?? this.page,
    generation: generation ?? this.generation,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
