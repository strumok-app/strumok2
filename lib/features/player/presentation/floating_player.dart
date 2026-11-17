import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/platform/device_class.dart';
import 'player_controller.dart';
import 'player_settings.dart';

part 'floating_player.g.dart';

/// Whether the session is shown in the in-app mini player (spec-06 §6.9); hidden whenever the session ends.
@Riverpod(keepAlive: true)
class FloatingPlayer extends _$FloatingPlayer {
  @override
  bool build() {
    ref.listen(playerControllerProvider.select((session) => session == null), (_, closed) {
      if (closed) state = false;
    });
    return false;
  }

  void hide() => state = false;

  /// The player route is gone: keep the video, playing or paused, in the mini player (not on TV, setting on);
  /// otherwise, or when it failed, stop.
  Future<void> leavePlayer() async {
    if (!ref.mounted) return;
    final controller = ref.read(playerControllerProvider.notifier);
    final session = ref.read(playerControllerProvider);
    final keep =
        ref.read(deviceClassProvider) != DeviceClass.tv &&
        ref.read(playerSettingsProvider).floatingPlayer &&
        session != null &&
        session.failure == null;
    if (keep) {
      state = true;
    } else {
      state = false;
      await controller.close();
    }
  }

  /// Stops playback.
  Future<void> close() async {
    state = false;
    await ref.read(playerControllerProvider.notifier).close();
  }
}
