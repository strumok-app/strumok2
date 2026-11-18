import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets/app_network_image.dart';
import '../../../app/widgets/focus_accent_bar.dart';
import '../../collection/domain/collection_item.dart';
import '../../collection/domain/progress.dart';
import 'details_providers.dart';

/// Episodes/chapters with preview images and per-item progress, one tab per section (season/volume) when there
/// are several. Opens on the section of [currentItem], which is highlighted and focused.
/// Shared by the details sheet, the player playlist and the reader chapter list.
class MediaItemsList extends StatelessWidget {
  final List<ContentMediaItem> items;
  final MediaType mediaType;

  /// Collection progress by item number; empty when the content is not in the collection.
  final Map<int, MediaItemPosition> positions;
  final int? currentItem;
  final ValueChanged<ContentMediaItem> onSelected;

  /// Extra widget at the end of a tile (e.g. download state); D-pad reaches it with →.
  final Widget Function(ContentMediaItem item)? trailing;

  const MediaItemsList({
    super.key,
    required this.items,
    required this.mediaType,
    required this.onSelected,
    this.positions = const {},
    this.currentItem,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final groups = groupBySection(items);
    final showImages = items.any((item) => item.image?.isNotEmpty ?? false);
    final currentGroup = max(0, groups.indexWhere((g) => g.$2.any((item) => item.number == currentItem)));

    _ItemList list(int index) => _ItemList(
      items: groups[index].$2,
      mediaType: mediaType,
      positions: positions,
      currentItem: currentItem,
      showImages: showImages,
      autofocus: index == currentGroup,
      onSelected: onSelected,
      trailing: trailing,
    );

    if (groups.length == 1) return list(0);

    return DefaultTabController(
      length: groups.length,
      initialIndex: currentGroup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              for (final (index, (section, _)) in groups.indexed)
                Tab(text: section == null || section.isEmpty ? '${index + 1}' : section),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: TabBarView(children: [for (var i = 0; i < groups.length; i++) list(i)])),
        ],
      ),
    );
  }
}

class _ItemList extends StatefulWidget {
  final List<ContentMediaItem> items;
  final MediaType mediaType;
  final Map<int, MediaItemPosition> positions;
  final int? currentItem;
  final bool showImages;
  final bool autofocus;
  final ValueChanged<ContentMediaItem> onSelected;
  final Widget Function(ContentMediaItem item)? trailing;

  const _ItemList({
    required this.items,
    required this.mediaType,
    required this.positions,
    required this.currentItem,
    required this.showImages,
    required this.autofocus,
    required this.onSelected,
    required this.trailing,
  });

  @override
  State<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<_ItemList> {
  static const _extent = _MediaItemTile.height + _MediaItemTile.gap;
  late final int _focusIndex = max(0, widget.items.indexWhere((item) => item.number == widget.currentItem));

  // Fixed extent lets the list open at the current item, so it is built and can take autofocus.
  late final _scroll = ScrollController(initialScrollOffset: max(0, _focusIndex - 1) * _extent);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels > position.maxScrollExtent) _scroll.jumpTo(position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    itemExtent: _extent,
    itemCount: widget.items.length,
    itemBuilder: (context, index) {
      final item = widget.items[index];
      return _MediaItemTile(
        item: item,
        mediaType: widget.mediaType,
        position: widget.positions[item.number],
        showImage: widget.showImages,
        selected: item.number == widget.currentItem,
        autofocus: widget.autofocus && index == _focusIndex,
        onTap: () => widget.onSelected(item),
        trailing: widget.trailing?.call(item),
      );
    },
  );
}

/// Outlined card: preview flush with the leading edge, title, and a progress bar along the bottom.
/// The current item is filled and marked with a play icon.
class _MediaItemTile extends StatefulWidget {
  static const height = 64.0;
  static const gap = 8.0;

  final ContentMediaItem item;
  final MediaType mediaType;
  final MediaItemPosition? position;
  final bool showImage;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;
  final Widget? trailing;

  _MediaItemTile({
    required this.item,
    required this.mediaType,
    required this.position,
    required this.showImage,
    required this.selected,
    required this.autofocus,
    required this.onTap,
    this.trailing,
  }) : super(key: ValueKey('mediaItem-${item.number}'));

  @override
  State<_MediaItemTile> createState() => _MediaItemTileState();
}

class _MediaItemTileState extends State<_MediaItemTile> {
  static const _radius = BorderRadius.all(Radius.circular(12));
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final position = widget.position;
    final progress = position == null ? 0.0 : mediaItemProgress(widget.mediaType, position) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: _MediaItemTile.gap),
      child: FocusAccentBar(
        focused: _focused,
        child: Material(
          color: widget.selected ? colors.surfaceContainerHighest : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: _radius,
            side: BorderSide(color: widget.selected ? colors.outline : colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _ink(theme, colors, progress)),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _ink(ThemeData theme, ColorScheme colors, double progress) => InkWell(
    autofocus: widget.autofocus,
    onTap: widget.onTap,
    onFocusChange: (focused) => setState(() => _focused = focused),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showImage) _Thumbnail(url: widget.item.image, mediaType: widget.mediaType, playing: widget.selected),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    spacing: 8,
                    children: [
                      if (widget.selected && !widget.showImage)
                        Icon(Icons.play_arrow, size: 20, color: colors.onSurface),
                      Expanded(
                        child: Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  final MediaType mediaType;
  final bool playing;

  const _Thumbnail({required this.url, required this.mediaType, required this.playing});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: mediaType == MediaType.video ? 80 : 48,
    child: Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(url ?? ''),
        if (playing)
          const Center(
            child: Icon(Icons.play_arrow, size: 36, color: Colors.white, shadows: [Shadow(blurRadius: 8)]),
          ),
      ],
    ),
  );
}
