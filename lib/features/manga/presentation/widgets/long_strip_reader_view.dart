import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/manga_reader_state.dart';
import 'chapter_edge.dart';
import 'manga_page_image.dart';
import 'reader_view.dart';
import 'reader_zoom.dart';

/// Continuous vertical scroll (spec-07). The list is anchored at the page it was opened (or jumped) at: pages above
/// it grow upwards as they load, so the page being read never shifts. The current page is the one crossing a line
/// at 30% of the screen, or the last page once the end is reached.
class LongStripReaderView extends StatefulWidget {
  /// Pages are not stretched beyond this width on wide screens.
  static const maxPageWidth = 800.0;

  final MangaReaderState state;
  final MangaPageConfig config;
  final ReaderViewController controller;
  final ReaderViewCallbacks callbacks;

  const LongStripReaderView({
    super.key,
    required this.state,
    required this.config,
    required this.controller,
    required this.callbacks,
  });

  @override
  State<LongStripReaderView> createState() => _LongStripReaderViewState();
}

class _LongStripReaderViewState extends State<LongStripReaderView> implements ReaderViewActions {
  static const _screenStep = 0.85;
  static const _smallStep = 1 / 3;
  static const _currentLine = 0.3;
  static const _scrollDuration = Duration(milliseconds: 250);

  final _centerKey = UniqueKey();
  final _viewportKey = GlobalKey();
  final _zoom = GlobalKey<ReaderZoomState>();
  final _scroll = ScrollController(keepScrollOffset: false);
  final _items = <int, BuildContext>{};
  late int _anchor = widget.state.page;
  var _anchorGeneration = 0;
  late int _current = widget.state.page;
  double? _scrollTarget;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  void didUpdateWidget(LongStripReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach(this);
      widget.controller.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    _scroll.dispose();
    super.dispose();
  }

  ScrollPosition? get _position => _scroll.hasClients ? _scroll.position : null;

  @override
  bool next() => _scrollBy(_screenStep);

  @override
  bool previous() => _scrollBy(-_screenStep);

  @override
  bool step(int direction) => _scrollBy(direction * _smallStep);

  @override
  void jumpToPage(int page) {
    setState(() {
      _anchor = page;
      _anchorGeneration++;
      _scrollTarget = null;
    });
    _setCurrent(page);
  }

  /// Scrolls by [screens] viewport heights; false when already at that end.
  bool _scrollBy(double screens) {
    final position = _position;
    if (position == null) return false;
    if (screens > 0 ? position.extentAfter < 1 : position.extentBefore < 1) return false;
    final from = _scrollTarget ?? position.pixels;
    final target = (from + position.viewportDimension * screens).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollTarget = target;
    _scroll.animateTo(target, duration: _scrollDuration, curve: Curves.easeOut);
    return true;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollEndNotification) _scrollTarget = null;
    if (notification is ScrollUpdateNotification || notification is ScrollEndNotification) _updateCurrent();
    return false;
  }

  void _updateCurrent() {
    final viewport = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final position = _position;
    if (viewport == null || !viewport.hasSize || position == null) return;
    final last = widget.state.pages.length - 1;
    int? page;
    if (position.extentAfter < 1 && _items.containsKey(last)) {
      page = last;
    } else {
      final line = viewport.size.height * _currentLine;
      for (final MapEntry(key: index, value: context) in _items.entries) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.attached || !box.hasSize) continue;
        final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (top <= line && top + box.size.height > line) {
          page = index;
          break;
        }
      }
    }
    if (page != null) _setCurrent(page);
  }

  void _setCurrent(int page) {
    if (page == _current) return;
    _current = page;
    widget.callbacks.onPageChanged(page);
  }

  void Function(PointerScrollEvent event)? _resolveWheel(PointerScrollEvent event) {
    final zoom = _zoom.currentState;
    if (zoom == null || !HardwareKeyboard.instance.isControlPressed) return null;
    return zoom.zoomByWheel;
  }

  Widget _page(int index, double width) => _StripItem(
    key: ValueKey(index),
    index: index,
    registry: _items,
    child: Center(
      child: SizedBox(
        width: width,
        child: MangaPageImage(page: widget.state.pages[index], number: index + 1, config: widget.config),
      ),
    ),
  );

  Widget _edge({required bool next}) {
    final state = widget.state;
    return ChapterEdge(
      key: ValueKey(next ? 'nextChapter' : 'previousChapter'),
      next: next,
      current: state.item?.title ?? '',
      target: state.items[state.itemIndex + (next ? 1 : -1)].title,
      onOpen: next ? widget.callbacks.onNextChapter : widget.callbacks.onPreviousChapter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final header = state.hasPrevious ? 1 : 0;
    final footer = state.hasNext ? 1 : 0;
    final after = state.pages.length - _anchor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, LongStripReaderView.maxPageWidth);
        return ReaderZoom(
          key: _zoom,
          onTap: widget.callbacks.onTap,
          child: ReaderWheelListener(
            resolve: _resolveWheel,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SizedBox.expand(
                key: _viewportKey,
                child: CustomScrollView(
                  key: ValueKey(('readerStrip', _anchorGeneration)),
                  controller: _scroll,
                  center: _centerKey,
                  slivers: [
                    // Laid out upwards from the anchor: index 0 is the page just above it.
                    SliverList.builder(
                      itemCount: _anchor + header,
                      itemBuilder: (context, i) => i < _anchor ? _page(_anchor - 1 - i, width) : _edge(next: false),
                    ),
                    SliverList.builder(
                      key: _centerKey,
                      itemCount: after + footer,
                      itemBuilder: (context, i) => i < after ? _page(_anchor + i, width) : _edge(next: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Registers its element by page index while built, for finding the current page.
class _StripItem extends StatefulWidget {
  final int index;
  final Map<int, BuildContext> registry;
  final Widget child;

  const _StripItem({super.key, required this.index, required this.registry, required this.child});

  @override
  State<_StripItem> createState() => _StripItemState();
}

class _StripItemState extends State<_StripItem> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.index] = context;
  }

  @override
  void didUpdateWidget(_StripItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || oldWidget.registry != widget.registry) {
      _unregister(oldWidget);
      widget.registry[widget.index] = context;
    }
  }

  @override
  void dispose() {
    _unregister(widget);
    super.dispose();
  }

  void _unregister(_StripItem item) {
    if (item.registry[item.index] == context) item.registry.remove(item.index);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
