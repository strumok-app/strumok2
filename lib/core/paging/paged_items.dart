/// Incrementally loaded list with 1-based pages (spec-01: search and channel pages start at 1).
final class PagedItems<T> {
  final List<T> items;
  final int nextPage;
  final bool loading;

  /// False after an empty page.
  final bool hasMore;

  /// Set when the last page failed; loading resumes only via retry.
  final Object? error;

  const PagedItems({this.items = const [], this.nextPage = 1, this.loading = false, this.hasMore = true, this.error});

  bool get canLoadMore => hasMore && !loading && error == null;

  /// Finished without any item.
  bool get isEmptyResult => items.isEmpty && !hasMore && !loading && error == null;

  PagedItems<T> startLoading() => PagedItems(items: items, nextPage: nextPage, loading: true, hasMore: hasMore);

  PagedItems<T> withPage(List<T> page) =>
      PagedItems(items: [...items, ...page], nextPage: nextPage + 1, hasMore: page.isNotEmpty);

  PagedItems<T> withError(Object error) => PagedItems(items: items, nextPage: nextPage, hasMore: hasMore, error: error);

  PagedItems<T> withoutError() => PagedItems(items: items, nextPage: nextPage, hasMore: hasMore);
}

/// Fetches the next page of [current]; errors are captured in the result.
Future<PagedItems<T>> fetchNextPage<T>(PagedItems<T> current, Future<List<T>> Function(int page) fetch) async {
  try {
    return current.withPage(await fetch(current.nextPage));
  } catch (e) {
    return current.withError(e);
  }
}
