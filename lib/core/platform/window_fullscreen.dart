import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

import 'app_platform.dart';

part 'window_fullscreen.g.dart';

/// Native window full screen (desktop); Android full screen is handled per screen with system UI modes.
abstract interface class WindowFullscreen {
  Future<void> setFullScreen(bool value);
}

class DesktopWindowFullscreen implements WindowFullscreen {
  const DesktopWindowFullscreen();

  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);
}

class NoWindowFullscreen implements WindowFullscreen {
  const NoWindowFullscreen();

  @override
  Future<void> setFullScreen(bool value) async {}
}

@Riverpod(keepAlive: true)
WindowFullscreen windowFullscreen(Ref ref) =>
    AppPlatform.current == AppPlatform.android ? const NoWindowFullscreen() : const DesktopWindowFullscreen();
