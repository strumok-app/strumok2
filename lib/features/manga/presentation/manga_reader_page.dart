import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/theme_settings.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../data/manga_page_images.dart';
import '../domain/manga_reader_preferences.dart';
import '../domain/manga_reader_state.dart';
import 'manga_reader_controller.dart';
import 'manga_reader_settings.dart';
import 'widgets/long_strip_reader_view.dart';
import 'widgets/manga_page_image.dart';
import 'widgets/paged_reader_view.dart';
import 'widgets/reader_overlay.dart';
import 'widgets/reader_view.dart';

/// Full-screen manga reader (spec-07); outside the app shell. One adaptive layout: tap zones and gestures for touch
/// and mouse, keys for keyboard and D-pad. OK/Enter or a tap in the middle toggles the controls; Back hides them,
/// then leaves.
class MangaReaderPage extends ConsumerStatefulWidget {
  final String supplier;
  final String id;

  /// Chapter index to open; null resumes `currentItem` from the collection.
  final int? item;

  const MangaReaderPage({super.key, required this.supplier, required this.id, this.item});

  @override
  ConsumerState<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends ConsumerState<MangaReaderPage> {
  static final _activateKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  final _views = ReaderViewController();
  final _retries = ReaderPageRetries();
  final _preloader = _PagePreloader();
  // Not a traversal target: arrows past the last control would land on the full-screen root.
  final _rootFocus = FocusNode(debugLabel: 'readerRoot', skipTraversal: true);
  final _sliderFocus = FocusNode(debugLabel: 'readerSlider');
  late final bool _immersive;
  var _controls = false;

  MangaReaderControllerProvider get _provider => mangaReaderControllerProvider(widget.supplier, widget.id);

  MangaReaderController get _controller => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    final deviceClass = ref.read(deviceClassProvider);
    _immersive = deviceClass == DeviceClass.phone || deviceClass == DeviceClass.tablet;
    if (_immersive) unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    // Providers must not change while the tree is building.
    unawaited(Future.microtask(() => mounted ? _controller.open(item: widget.item) : null));
  }

  @override
  void dispose() {
    if (_immersive) unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _preloader.dispose();
    _rootFocus.dispose();
    _sliderFocus.dispose();
    super.dispose();
  }

  void _setControls(bool visible, {bool focus = false}) {
    if (visible != _controls) setState(() => _controls = visible);
    if (!visible) {
      // Hidden controls must not keep focus: keys would reach them invisibly, or no longer reach the root.
      if (!_rootFocus.hasPrimaryFocus) _rootFocus.requestFocus();
    } else if (focus) {
      // The controls accept focus only after they are rebuilt as visible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controls) _sliderFocus.requestFocus();
      });
    }
  }

  void _next() {
    if (!_views.next()) unawaited(_controller.nextChapter());
  }

  void _previous() {
    if (!_views.previous()) unawaited(_controller.previousChapter());
  }

  void _step(int direction) {
    if (_views.step(direction)) return;
    unawaited(direction > 0 ? _controller.nextChapter() : _controller.previousChapter());
  }

  /// Thirds of the screen: previous / controls / next, along the reading direction.
  void _onTap(Offset position, Size size) {
    final mode = ref.read(mangaReaderSettingsProvider).mode;
    final fraction = mode.horizontal ? position.dx / size.width : position.dy / size.height;
    var zone = fraction < 1 / 3 ? -1 : (fraction > 2 / 3 ? 1 : 0);
    if (mode == MangaReaderMode.rightToLeft) zone = -zone;
    if (zone == 0) return _setControls(!_controls);
    _setControls(false);
    zone > 0 ? _next() : _previous();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final state = ref.read(_provider);

    // Unhandled Back leaves the reader (app-level Escape action / Android system back).
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (!_controls || !state.ready) return KeyEventResult.ignored;
      if (!repeat) _setControls(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext || key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (!repeat) {
        unawaited(key == LogicalKeyboardKey.mediaTrackNext ? _controller.nextChapter() : _controller.previousChapter());
      }
      return KeyEventResult.handled;
    }
    // Focus is in the controls: regular traversal and activation.
    if (!node.hasPrimaryFocus || !state.ready) return KeyEventResult.ignored;

    if (_activateKeys.contains(key)) {
      if (repeat) return KeyEventResult.handled;
      if (!_retries.retry(state.pages[state.page])) _setControls(!_controls, focus: true);
      return KeyEventResult.handled;
    }
    final rtl = ref.read(mangaReaderSettingsProvider).mode == MangaReaderMode.rightToLeft;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final VoidCallback? action = switch (key) {
      LogicalKeyboardKey.space => shift ? _previous : _next,
      LogicalKeyboardKey.pageDown => _next,
      LogicalKeyboardKey.pageUp => _previous,
      LogicalKeyboardKey.arrowRight => rtl ? _previous : _next,
      LogicalKeyboardKey.arrowLeft => rtl ? _next : _previous,
      LogicalKeyboardKey.arrowDown => () => _step(1),
      LogicalKeyboardKey.arrowUp => () => _step(-1),
      _ => null,
    };
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  Widget _content(MangaReaderState state, MangaReaderPreferences settings, MangaPageConfig config) {
    if (state.failure != null) return _ReaderFailureView(state: state);
    if (!state.ready) return const Center(child: CircularProgressIndicator());
    final callbacks = ReaderViewCallbacks(
      onPageChanged: (page) => unawaited(_controller.setPage(page)),
      onTap: _onTap,
      onNextChapter: () => unawaited(_controller.nextChapter()),
      onPreviousChapter: () => unawaited(_controller.previousChapter()),
    );
    // A new page list or mode starts a new view at the controller's page.
    final key = ValueKey((state.generation, settings.mode));
    return settings.mode == MangaReaderMode.longStrip
        ? LongStripReaderView(key: key, state: state, config: config, controller: _views, callbacks: callbacks)
        : PagedReaderView(
            key: key,
            state: state,
            mode: settings.mode,
            config: config,
            controller: _views,
            callbacks: callbacks,
          );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    ref.listen(_provider, (previous, next) {
      if (previous?.ready == true || !next.ready) return;
      // The failure view's Retry held focus; keys must reach the root again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_rootFocus.hasFocus) _rootFocus.requestFocus();
      });
    });
    final settings = ref.watch(mangaReaderSettingsProvider);
    final dark = settings.background == MangaReaderBackground.dark;
    final config = MangaPageConfig(
      images: ref.watch(mangaPageImagesProvider),
      headers: state.source?.headers,
      autoCrop: settings.autoCrop,
      strip: settings.mode == MangaReaderMode.longStrip,
      retries: _retries,
    );
    if (state.ready) {
      _preloader.update(config, [for (final i in preloadPages(state.page, state.pages.length)) state.pages[i]]);
    }

    return Theme(
      data: buildTheme(ref.watch(themeColorSchemeProvider), dark ? Brightness.dark : Brightness.light),
      child: Scaffold(
        backgroundColor: dark ? Colors.black : Colors.white,
        body: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _content(state, settings, config),
              Align(
                alignment: Alignment.topCenter,
                child: _Reveal(
                  visible: _controls || !state.ready,
                  hiddenOffset: const Offset(0, -1),
                  child: ReaderTopBar(
                    state: state,
                    back: ref.watch(deviceClassProvider) != DeviceClass.tv,
                    onSelectChapter: (index) => unawaited(_controller.selectItem(index)),
                    onSelectSource: (index) => unawaited(_controller.selectSource(index)),
                  ),
                ),
              ),
              if (state.ready)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _Reveal(
                    visible: _controls,
                    hiddenOffset: const Offset(0, 1),
                    child: ReaderBottomBar(
                      state: state,
                      rightToLeft: settings.mode == MangaReaderMode.rightToLeft,
                      sliderFocus: _sliderFocus,
                      onJump: _views.jumpToPage,
                      onPreviousChapter: () => unawaited(_controller.previousChapter()),
                      onNextChapter: () => unawaited(_controller.nextChapter()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides a bar in and out; hidden, it takes neither pointer nor focus.
class _Reveal extends StatelessWidget {
  final bool visible;
  final Offset hiddenOffset;
  final Widget child;

  const _Reveal({required this.visible, required this.hiddenOffset, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : hiddenOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    ),
  );
}

/// Failure message with Retry (focused) and, when there are several, Change translation.
class _ReaderFailureView extends ConsumerStatefulWidget {
  final MangaReaderState state;

  const _ReaderFailureView({required this.state});

  @override
  ConsumerState<_ReaderFailureView> createState() => _ReaderFailureViewState();
}

class _ReaderFailureViewState extends ConsumerState<_ReaderFailureView> {
  final _retryFocus = FocusNode(debugLabel: 'readerRetry');

  @override
  void initState() {
    super.initState();
    // The reader root holds focus (autofocus would not move it); D-pad users land on Retry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _retryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final controller = ref.read(mangaReaderControllerProvider(state.supplier, state.id).notifier);
    final message = switch (state.failure!) {
      MangaReaderFailure.loadFailed => l10n.readerLoadFailed,
      MangaReaderFailure.noPages => l10n.readerNoPages,
    };
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(message, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    key: const Key('readerRetry'),
                    focusNode: _retryFocus,
                    onPressed: () => unawaited(controller.retry()),
                    child: Text(l10n.commonRetry),
                  ),
                  if (state.sources.length > 1)
                    FilledButton.tonal(
                      onPressed: () =>
                          showReaderSources(context, state, (index) => unawaited(controller.selectSource(index))),
                      child: Text(l10n.readerChangeTranslation),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps the pages around the current one loading and decoded (spec-07: ±2), with their crop bounds computed.
class _PagePreloader {
  final _streams = <String, (ImageStream, ImageStreamListener)>{};
  MangaPageConfig? _config;

  void update(MangaPageConfig config, List<String> pages) {
    final old = _config;
    if (old == null ||
        old.images != config.images ||
        !mapEquals(old.headers, config.headers) ||
        old.autoCrop != config.autoCrop ||
        old.cropVertical != config.cropVertical) {
      dispose();
    }
    _config = config;
    final wanted = pages.toSet();
    for (final page in _streams.keys.where((p) => !wanted.contains(p)).toList()) {
      _remove(page);
    }
    for (final page in wanted.where((p) => !_streams.containsKey(p))) {
      final stream = config.images.provider(page, headers: config.headers).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) => unawaited(_cropAndRelease(config, page, info)),
        // The page itself shows the error with Retry when it is opened.
        onError: (_, _) {},
      );
      stream.addListener(listener);
      _streams[page] = (stream, listener);
    }
  }

  static Future<void> _cropAndRelease(MangaPageConfig config, String page, ImageInfo info) async {
    try {
      if (config.autoCrop) await config.images.crop(page, info.image, vertical: config.cropVertical);
    } finally {
      info.dispose();
    }
  }

  void _remove(String page) {
    final entry = _streams.remove(page);
    if (entry != null) entry.$1.removeListener(entry.$2);
  }

  void dispose() {
    for (final page in _streams.keys.toList()) {
      _remove(page);
    }
  }
}
