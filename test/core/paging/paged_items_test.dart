import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/paging/paged_items.dart';

void main() {
  test('pages are 1-based and appended until an empty page', () async {
    final requested = <int>[];
    Future<List<int>> fetch(int page) async {
      requested.add(page);
      return page <= 2 ? [page * 10, page * 10 + 1] : const [];
    }

    var state = const PagedItems<int>();
    state = await fetchNextPage(state.startLoading(), fetch);
    state = await fetchNextPage(state.startLoading(), fetch);
    expect(state.items, [10, 11, 20, 21]);
    expect(state.canLoadMore, isTrue);

    state = await fetchNextPage(state.startLoading(), fetch);
    expect(requested, [1, 2, 3]);
    expect(state.hasMore, isFalse);
    expect(state.canLoadMore, isFalse);
    expect(state.isEmptyResult, isFalse);
  });

  test('error keeps items and blocks loading until cleared', () async {
    var state = const PagedItems<int>(items: [1], nextPage: 2);
    state = await fetchNextPage(state.startLoading(), (_) async => throw StateError('boom'));
    expect(state.items, [1]);
    expect(state.error, isA<StateError>());
    expect(state.canLoadMore, isFalse);

    state = state.withoutError();
    expect(state.canLoadMore, isTrue);
    expect(state.nextPage, 2);
  });

  test('empty first page is an empty result', () async {
    final state = await fetchNextPage(const PagedItems<int>().startLoading(), (_) async => <int>[]);
    expect(state.isEmptyResult, isTrue);
  });
}
