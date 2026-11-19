import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strumok/app/widgets/trailing_fade.dart';

import '../../core/localization.dart';
import '../../core/paging/paged_items.dart';
import '../../core/platform/device_class.dart';
import 'content_card.dart';
import 'content_row_frame.dart';
import 'random_pick_dialog.dart';

/// Horizontal list of content cards with independent paging (spec-01): lazy load-more for touch/mouse,
/// an explicit focusable "Load more" tile on TV.
class ContentRow extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final PagedItems<ContentInfo> state;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetry;
  final bool hideWhenEmpty;
  final bool autofocusFirst;

  /// Header action reloading the row from its first page.
  final VoidCallback? onReload;

  /// Header action picking a random item out of this pool.
  final Future<List<ContentInfo>> Function()? randomPool;

  const ContentRow({
    super.key,
    required this.title,
    required this.state,
    this.subtitle,
    this.onLoadMore,
    this.onRetry,
    this.hideWhenEmpty = false,
    this.autofocusFirst = false,
    this.onReload,
    this.randomPool,
  });

  /// Static list without paging.
  ContentRow.items({
    super.key,
    required this.title,
    required List<ContentInfo> items,
    this.subtitle,
    this.autofocusFirst = false,
  }) : state = PagedItems(items: items, hasMore: false),
       onLoadMore = null,
       onRetry = null,
       onReload = null,
       randomPool = null,
       hideWhenEmpty = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hideWhenEmpty && state.isEmptyResult) return const SizedBox.shrink();

    final l10n = context.l10n;
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final cardWidth = isTv ? 160.0 : 136.0;
    final rowHeight = cardWidth / posterAspectRatio + 72 + 2 * contentCardInset;
    final items = state.items;

    void requestMore() {
      if (state.canLoadMore && onLoadMore != null) WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore!());
    }

    final Widget body;
    if (items.isEmpty) {
      body = switch (state) {
        PagedItems(error: _?) => _RowMessage(
          message: l10n.errorLoading,
          action: onRetry == null ? null : TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ),
        PagedItems(isEmptyResult: true) => _RowMessage(message: l10n.rowEmpty),
        _ => const Center(child: CircularProgressIndicator()),
      };
    } else {
      final showLoadMoreTile = isTv && state.canLoadMore && onLoadMore != null;
      final trailing = state.loading || state.error != null || showLoadMoreTile ? 1 : 0;
      body = FocusTraversalGroup(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16 - contentCardInset, vertical: 8 - contentCardInset),
          clipBehavior: Clip.none,
          itemCount: items.length + trailing,
          separatorBuilder: (_, _) => const SizedBox(width: 12 - 2 * contentCardInset),
          itemBuilder: (context, index) {
            if (index < items.length) {
              if (!isTv && index >= items.length - 4) requestMore();
              return ContentCard(info: items[index], width: cardWidth, autofocus: autofocusFirst && index == 0);
            }
            return Padding(
              padding: const EdgeInsets.all(contentCardInset),
              child: SizedBox(
                width: cardWidth,
                child: AspectRatio(
                  aspectRatio: posterAspectRatio,
                  child: switch (state) {
                    PagedItems(loading: true) => const Center(child: CircularProgressIndicator()),
                    PagedItems(error: _?) => Center(
                      child: FilledButton.tonal(onPressed: onRetry, child: Text(l10n.commonRetry)),
                    ),
                    _ => FilledButton.tonal(
                      onPressed: onLoadMore,
                      // Poster-shaped tile, so it keeps the card radius instead of the pill button shape.
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          const Icon(Icons.more_horiz),
                          Text(l10n.rowLoadMore, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return ContentRowFrame(
      title: title,
      label: subtitle,
      actions: [
        if (randomPool case final pool?)
          RowAction(
            key: const Key('rowPickRandom'),
            icon: Icons.casino_outlined,
            tooltip: l10n.rowPickRandom,
            onPressed: () => showRandomPickDialog(context, loadPool: pool),
          ),
        if (onReload case final reload?)
          RowAction(key: const Key('rowReload'), icon: Icons.refresh, tooltip: l10n.rowReload, onPressed: reload),
      ],
      body: SizedBox(
        height: rowHeight,
        child: TrailingFade(child: body),
      ),
    );
  }
}

class _RowMessage extends StatelessWidget {
  final String message;
  final Widget? action;

  const _RowMessage({required this.message, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      spacing: 8,
      children: [
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ?action,
      ],
    ),
  );
}
