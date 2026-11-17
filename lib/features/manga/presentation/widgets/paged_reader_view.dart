import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/manga_reader_preferences.dart';
import '../../domain/manga_reader_state.dart';
import 'chapter_edge.dart';
import 'manga_page_image.dart';
import 'reader_view.dart';
import 'reader_zoom.dart';

/// One page at a time: vertical, left-to-right or right-to-left (spec-07). An extra page past the ends offers the
/// neighboring chapter. While zoomed, swiping pans instead of turning pages; a page turn resets the zoom.
class PagedReaderView extends StatefulWidget {
  final MangaReaderState state;
  final MangaReaderMode mode;
  final MangaPageConfig config;
  final ReaderViewController controller;
  final ReaderViewCallbacks callbacks;

  const PagedReaderView({
    super.key,
    required this.state,
    required this.mode,
    required this.config,
    required this.controller,
    required this.callbacks,
  });

  @override
  State<PagedReaderView> createState() => _PagedReaderViewState();
}

class _PagedReaderViewState extends State<PagedReaderView> implements ReaderViewActions {
  static const _turnDuration = Duration(milliseconds: 220);
  static const _wheelThreshold = 40.0;
  static const _wheelCooldown = Duration(milliseconds: 300);

  late final int _leading = widget.state.hasPrevious ? 1 : 0;
  late final int _trailing = widget.state.hasNext ? 1 : 0;
  late final _pager = PageController(initialPage: widget.state.page + _leading);
  final _zoom = GlobalKey<ReaderZoomState>();
  late int _index = widget.state.page + _leading;
  var _zoomed = false;
  double _wheel = 0;
  var _lastWheelTurn = DateTime(0);

  int get _count => _leading + widget.state.pages.length + _trailing;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  void didUpdateWidget(PagedReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach(this);
      widget.controller.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    _pager.dispose();
    super.dispose();
  }

  int get _settledIndex => _pager.hasClients ? (_pager.page ?? _index.toDouble()).round() : _index;

  @override
  bool next() => _go(_settledIndex + 1);

  @override
  bool previous() => _go(_settledIndex - 1);

  @override
  bool step(int direction) => direction > 0 ? next() : previous();

  @override
  void jumpToPage(int page) {
    _zoom.currentState?.reset();
    _pager.jumpToPage(page + _leading);
  }

  bool _go(int index) {
    if (index < 0 || index >= _count) return false;
    _zoom.currentState?.reset();
    _pager.animateToPage(index, duration: _turnDuration, curve: Curves.easeOut);
    return true;
  }

  void _onPageChanged(int index) {
    _index = index;
    _zoom.currentState?.reset();
    final page = index - _leading;
    if (page >= 0 && page < widget.state.pages.length) widget.callbacks.onPageChanged(page);
  }

  void Function(PointerScrollEvent event)? _resolveWheel(PointerScrollEvent event) {
    final zoom = _zoom.currentState;
    if (zoom == null) return null;
    if (HardwareKeyboard.instance.isControlPressed) return zoom.zoomByWheel;
    if (zoom.zoomed) return (e) => zoom.panBy(-e.scrollDelta);
    return _turnByWheel;
  }

  /// One page per wheel notch; a trackpad's stream of small deltas adds up to one.
  void _turnByWheel(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    final now = DateTime.now();
    if (now.difference(_lastWheelTurn) < _wheelCooldown) {
      _wheel = 0;
      return;
    }
    _wheel += delta;
    if (_wheel.abs() < _wheelThreshold) return;
    final forward = _wheel > 0;
    _wheel = 0;
    _lastWheelTurn = now;
    if (forward && !next()) widget.callbacks.onNextChapter();
    if (!forward && !previous()) widget.callbacks.onPreviousChapter();
  }

  Widget _item(int index) {
    final state = widget.state;
    final page = index - _leading;
    if (page < 0) {
      return ChapterEdge(
        next: false,
        current: state.item?.title ?? '',
        target: state.items[state.itemIndex - 1].title,
        onOpen: widget.callbacks.onPreviousChapter,
      );
    }
    if (page >= state.pages.length) {
      return ChapterEdge(
        next: true,
        current: state.item?.title ?? '',
        target: state.items[state.itemIndex + 1].title,
        onOpen: widget.callbacks.onNextChapter,
      );
    }
    return MangaPageImage(
      key: ValueKey(state.pages[page]),
      page: state.pages[page],
      number: page + 1,
      config: widget.config,
    );
  }

  @override
  Widget build(BuildContext context) => ReaderZoom(
    key: _zoom,
    onTap: widget.callbacks.onTap,
    onZoomChanged: (zoomed) => setState(() => _zoomed = zoomed),
    child: ReaderWheelListener(
      resolve: _resolveWheel,
      child: PageView.builder(
        key: const Key('readerPager'),
        controller: _pager,
        scrollDirection: widget.mode.horizontal ? Axis.horizontal : Axis.vertical,
        reverse: widget.mode == MangaReaderMode.rightToLeft,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        allowImplicitScrolling: true,
        onPageChanged: _onPageChanged,
        itemCount: _count,
        itemBuilder: (context, index) => _item(index),
      ),
    ),
  );
}
