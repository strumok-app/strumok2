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
  @override
  PagedItems<ContentInfo> build(String supplier, String channel) {
    ref.watch(suppliersProvider);
    Future.microtask(loadMore);
    return const PagedItems();
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final current = state.startLoading();
    state = current;
    final next = await fetchNextPage(current, (page) async {
      final source = ref.read(supplierByNameProvider(supplier));
      return source.loadChannel(channel, page: page);
    });
    if (ref.mounted) state = next;
  }

  Future<void> retry() async {
    state = state.withoutError();
    await loadMore();
  }
}
