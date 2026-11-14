import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/platform/window_fullscreen.dart';

part 'player_fullscreen.g.dart';

/// Desktop window full screen while in the player; left when the player closes.
@Riverpod(keepAlive: true)
class PlayerFullscreen extends _$PlayerFullscreen {
  @override
  bool build() => false;

  Future<void> set(bool value) async {
    if (!ref.mounted || value == state) return;
    state = value;
    await ref.read(windowFullscreenProvider).setFullScreen(value);
  }

  Future<void> toggle() => set(!state);
}
