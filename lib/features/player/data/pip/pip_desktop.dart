import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import 'pip.dart';

final _log = Logger('DesktopPip');

/// Window operations used by [DesktopPip].
abstract interface class PipWindow {
  Future<bool> isFullScreen();
  Future<void> setFullScreen(bool value);
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<void> setSize(Size size);
  Future<void> setFrameless(bool value);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> alignBottomRight();
  Future<void> close();
  Future<void> startDragging();
}

class WindowManagerPipWindow implements PipWindow {
  const WindowManagerPipWindow();

  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> unmaximize() => windowManager.unmaximize();

  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<void> setBounds(Rect bounds) => windowManager.setBounds(bounds);

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> setFrameless(bool value) =>
      windowManager.setTitleBarStyle(value ? TitleBarStyle.hidden : TitleBarStyle.normal);

  @override
  Future<void> setAlwaysOnTop(bool value) => windowManager.setAlwaysOnTop(value);

  @override
  Future<void> alignBottomRight() => windowManager.setAlignment(Alignment.bottomRight);

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}

/// Long side 576 px with the video aspect ratio (clamped to 9:16..21:9).
Size compactWindowSize(double aspectRatio, {double longSide = 576}) {
  final ratio = aspectRatio.isFinite && aspectRatio > 0
      ? aspectRatio.clamp(9 / 16, 21 / 9).toDouble()
      : PipPlayback.defaultAspectRatio;
  return ratio >= 1 ? Size(longSide, longSide / ratio) : Size(longSide * ratio, longSide);
}

/// Desktop PiP: a compact, frameless, always-on-top window (spec-06 §6.10). The previous bounds, maximized and
/// full screen state are restored on exit. Window transitions are async and never interleave.
class DesktopPip extends Pip {
  static const _fallbackBounds = Size(1280, 720);

  final PipWindow _window;

  /// Lets the window manager apply a change before the next one (frame/size changes race on Linux).
  final Duration settleDelay;

  bool _enabled = false;
  double _aspectRatio = PipPlayback.defaultAspectRatio;
  Rect? _restoreBounds;
  bool _restoreMaximized = false;
  bool _restoreFullScreen = false;
  Future<void> _transitions = Future.value();

  DesktopPip(this._window, {this.settleDelay = const Duration(milliseconds: 100)});

  @override
  bool get isSupported => true;

  Future<void> _settle() => settleDelay == Duration.zero ? Future.value() : Future.delayed(settleDelay);

  Future<void> _enqueue(Future<void> Function() transition) => _transitions = _transitions.then((_) async {
    try {
      await transition();
    } catch (e, st) {
      _log.warning('PiP window transition failed', e, st);
    }
  });

  @override
  Future<void> enable() async => _enabled = true;

  @override
  Future<void> disable() async {
    _enabled = false;
    await exit();
  }

  @override
  Future<void> updatePlayback(PipPlayback playback) async {
    if (playback.aspectRatio.isFinite && playback.aspectRatio > 0) _aspectRatio = playback.aspectRatio;
  }

  @override
  Future<void> enter() {
    if (!_enabled || isActive.value) return _transitions;
    active = true;
    return _enqueue(() async {
      _restoreFullScreen = await _window.isFullScreen();
      if (_restoreFullScreen) {
        await _window.setFullScreen(false);
        await _settle();
      }
      _restoreMaximized = await _window.isMaximized();
      if (_restoreMaximized) {
        await _window.unmaximize();
        await _settle();
      }
      _restoreBounds = await _window.getBounds();
      await _window.setFrameless(true);
      await _settle();
      await _window.setSize(compactWindowSize(_aspectRatio));
      await _window.setAlwaysOnTop(true);
      await _settle();
      await _window.alignBottomRight();
    });
  }

  @override
  Future<void> exit() {
    if (!isActive.value) return _transitions;
    active = false;
    return _enqueue(() async {
      await _window.setAlwaysOnTop(false);
      await _window.setFrameless(false);
      await _settle();
      final bounds = _restoreBounds;
      await _window.setBounds(bounds ?? Offset.zero & _fallbackBounds);
      if (_restoreMaximized) {
        await _settle();
        await _window.maximize();
      }
      if (_restoreFullScreen) {
        await _settle();
        await _window.setFullScreen(true);
      }
    });
  }

  @override
  Future<void> closeApp() => _window.close();

  @override
  Future<void> startWindowDrag() async {
    if (isActive.value) await _window.startDragging();
  }
}
