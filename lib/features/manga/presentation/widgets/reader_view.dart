import 'package:flutter/widgets.dart';

/// Navigation the reader page drives (keys, tap zones, slider); implemented by the paged and strip views.
abstract interface class ReaderViewActions {
  /// Forward by a page (paged) or a screen (strip); false at the end of the chapter.
  bool next();

  /// Backward by a page (paged) or a screen (strip); false at the start of the chapter.
  bool previous();

  /// Small step for ↑/↓: a page (paged) or a third of the screen (strip); false at that end.
  bool step(int direction);

  void jumpToPage(int page);
}

/// Handle to the view currently shown; views attach themselves while mounted.
class ReaderViewController implements ReaderViewActions {
  ReaderViewActions? _view;

  void attach(ReaderViewActions view) => _view = view;

  void detach(ReaderViewActions view) {
    if (identical(_view, view)) _view = null;
  }

  @override
  bool next() => _view?.next() ?? false;

  @override
  bool previous() => _view?.previous() ?? false;

  @override
  bool step(int direction) => _view?.step(direction) ?? false;

  @override
  void jumpToPage(int page) => _view?.jumpToPage(page);
}

/// What a reader view needs from the page.
class ReaderViewCallbacks {
  final ValueChanged<int> onPageChanged;
  final void Function(Offset position, Size size) onTap;
  final VoidCallback onNextChapter;
  final VoidCallback onPreviousChapter;

  const ReaderViewCallbacks({
    required this.onPageChanged,
    required this.onTap,
    required this.onNextChapter,
    required this.onPreviousChapter,
  });
}
