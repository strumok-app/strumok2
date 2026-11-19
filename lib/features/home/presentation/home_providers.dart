import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/paging/paged_items.dart';
import '../../suppliers/data/supplier_registry.dart';
import '../../suppliers/presentation/supplier_configs.dart';

part 'home_providers.g.dart';

typedef HomeRow = ({String supplier, String channel});

/// Enabled suppliers in user order, each with its selected channels in supplier order (spec-01 Home).
@Riverpod(keepAlive: true)
List<HomeRow> homeRows(Ref ref) => [
  for (final config in ref.watch(supplierConfigsProvider))
    if (config.enabled)
      for (final channel in config.supplier.channels)
        if (config.channels.contains(channel)) (supplier: config.name, channel: channel),
];

/// One recommendation row; kept alive so Home keeps its rows when navigating away and back.
@Riverpod(keepAlive: true)
class ChannelItems extends _$ChannelItems {
  /// Random pick loads more pages until the row has this many items...
  static const randomPoolSize = 60;

  /// ...but at most this many extra pages.
  static const randomPoolMaxExtraPages = 3;

  /// Bumped by [reload]; pages requested before it are dropped.
  var _generation = 0;

  /// Latest page request.
  Future<void>? _pending;

  @override
  PagedItems<ContentInfo> build(String supplier, String channel) {
    ref.watch(suppliersProvider);
    _generation++;
    Future.microtask(loadMore);
    return const PagedItems();
  }

  Future<void> loadMore() {
    if (!state.canLoadMore) return _pending ?? Future.value();
    return _pending = _loadNext();
  }

  Future<void> _loadNext() async {
    final generation = _generation;
    final current = state.startLoading();
    state = current;
    final next = await fetchNextPage(current, (page) async {
      final source = ref.read(supplierByNameProvider(supplier));
      return source.loadChannel(channel, page: page);
    });
    if (ref.mounted && generation == _generation) state = next;
  }

  Future<void> retry() async {
    state = state.withoutError();
    await loadMore();
  }

  /// Drops loaded pages and loads the row again from page 1.
  Future<void> reload() {
    _generation++;
    state = const PagedItems();
    return loadMore();
  }

  /// Items to pick a random one from: waits for a page in flight and loads a few more pages first, so the pick is
  /// not limited to page 1.
  Future<List<ContentInfo>> randomPool() async {
    var extraPages = 0;
    while (state.items.length < randomPoolSize) {
      if (state.loading) {
        await _pending;
      } else if (state.canLoadMore && extraPages < randomPoolMaxExtraPages) {
        extraPages++;
        await loadMore();
      } else {
        break;
      }
      if (!ref.mounted) return const [];
    }
    return state.items;
  }
}
