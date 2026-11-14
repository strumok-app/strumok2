import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization.dart';
import '../../../data/video_backend.dart';
import '../../../domain/player_session.dart';
import '../../player_controller.dart';
import '../../player_fullscreen.dart';
import '../../widgets/player_widgets.dart';

/// Mouse + keyboard controls (spec-06 §6.6): the keyboard map works regardless of overlay visibility; the overlay
/// shows on hover/keys and hides (with the cursor) after inactivity while playing.
class DesktopControls extends ConsumerStatefulWidget {
  final PlayerSession session;

  const DesktopControls({super.key, required this.session});

  @override
  ConsumerState<DesktopControls> createState() => _DesktopControlsState();
}

class _DesktopControlsState extends ConsumerState<DesktopControls> {
  static const _seekStep = Duration(seconds: 10);
  static const _longSeekStep = Duration(seconds: 60);
  static const _volumeStep = 5.0;

  late final PlayerController _controller;
  late final PlayerFullscreen _fullscreen;
  late final ControlsVisibility _visibility;
  final _rootFocus = FocusNode(debugLabel: 'playerRoot');

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
    _fullscreen = ref.read(playerFullscreenProvider.notifier);
    _visibility = ControlsVisibility(() => _controller.status)..addListener(_onVisibility);
  }

  @override
  void dispose() {
    _visibility.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  void _onVisibility() {
    if (!_visibility.visible && _rootFocus.hasFocus) _rootFocus.requestFocus();
    setState(() {});
  }

  void _changeVolume(double delta) => unawaited(_controller.setVolume(_controller.status.value.volume + delta));

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final fullscreen = ref.read(playerFullscreenProvider);

    final handled = switch (event.logicalKey) {
      LogicalKeyboardKey.space || LogicalKeyboardKey.mediaPlayPause when !repeat => _run(_controller.playOrPause),
      LogicalKeyboardKey.mediaPlay => _run(_controller.play),
      LogicalKeyboardKey.mediaPause => _run(_controller.pause),
      LogicalKeyboardKey.arrowLeft when shift => _run(() => _controller.frameStep(forward: false)),
      LogicalKeyboardKey.arrowRight when shift => _run(() => _controller.frameStep(forward: true)),
      LogicalKeyboardKey.arrowLeft => _run(() => _controller.seekBy(-_seekStep)),
      LogicalKeyboardKey.arrowRight => _run(() => _controller.seekBy(_seekStep)),
      LogicalKeyboardKey.keyJ => _run(() => _controller.seekBy(-_longSeekStep)),
      LogicalKeyboardKey.keyI => _run(() => _controller.seekBy(_longSeekStep)),
      LogicalKeyboardKey.arrowUp => _run(() async => _changeVolume(_volumeStep)),
      LogicalKeyboardKey.arrowDown => _run(() async => _changeVolume(-_volumeStep)),
      LogicalKeyboardKey.bracketRight || LogicalKeyboardKey.mediaTrackNext when !repeat => _run(_controller.next),
      LogicalKeyboardKey.bracketLeft ||
      LogicalKeyboardKey.mediaTrackPrevious when !repeat => _run(_controller.previous),
      LogicalKeyboardKey.keyF when !repeat => _run(_fullscreen.toggle),
      LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter when !repeat => _run(() => _fullscreen.set(true)),
      // Not handled when windowed: the app-level Escape then leaves the player.
      LogicalKeyboardKey.escape when fullscreen => _run(() => _fullscreen.set(false)),
      LogicalKeyboardKey.keyP when !repeat && widget.session.items.length > 1 => _run(
        () => showPlaylistPanel(context, widget.session),
      ),
      _ => false,
    };
    if (handled) _visibility.show();
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _run(Future<void> Function() action) {
    unawaited(action());
    return true;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      _changeVolume(event.scrollDelta.dy < 0 ? _volumeStep : -_volumeStep);
      _visibility.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    final status = _controller.status;
    final fullscreen = ref.watch(playerFullscreenProvider);
    final visible = _visibility.visible || session.failure != null;

    return Focus(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: visible ? MouseCursor.defer : SystemMouseCursors.none,
        onHover: (_) => _visibility.show(),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video area only, so double-tap detection never delays the buttons.
              GestureDetector(
                key: const Key('playerSurface'),
                behavior: HitTestBehavior.opaque,
                onTap: _controller.playOrPause,
                onDoubleTap: _fullscreen.toggle,
              ),
              PlayerBufferingIndicator(session: session, status: status),
              IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      ControlsScrim(top: true, child: PlayerTopBar(session: session)),
                      const Spacer(),
                      ControlsScrim(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerSeekBar(status: status, onSeek: _controller.seekTo, focusable: false),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: l10n.playerPrevious,
                                    onPressed: session.hasPrevious ? _controller.previous : null,
                                    icon: const Icon(Icons.skip_previous),
                                  ),
                                  PlayPauseButton(status: status, onPressed: _controller.playOrPause),
                                  IconButton(
                                    tooltip: l10n.playerNext,
                                    onPressed: session.hasNext ? _controller.next : null,
                                    icon: const Icon(Icons.skip_next),
                                  ),
                                  _VolumeControl(status: status, onChanged: _controller.setVolume),
                                  const SizedBox(width: 8),
                                  PlayerTimeLabel(status: status),
                                  const Spacer(),
                                  if (session.sources.length > 1)
                                    SourceButton(session: session, onSelected: _controller.selectSource),
                                  if (session.items.length > 1) PlaylistButton(session: session),
                                  IconButton(
                                    key: const Key('fullscreenButton'),
                                    tooltip: fullscreen ? l10n.playerExitFullscreen : l10n.playerFullscreen,
                                    onPressed: _fullscreen.toggle,
                                    icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (session.failure != null) PlayerFailureView(session: session),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mute toggle (restores the previous level) and a volume slider.
class _VolumeControl extends StatefulWidget {
  final ValueListenable<PlaybackStatus> status;
  final ValueChanged<double> onChanged;

  const _VolumeControl({required this.status, required this.onChanged});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  // Not focusable: ↑/↓ change the volume through the key map.
  final _sliderFocus = FocusNode(canRequestFocus: false, skipTraversal: true);
  double _beforeMute = 100;

  @override
  void dispose() {
    _sliderFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.status,
    builder: (context, status, _) {
      final muted = status.volume <= 0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: muted ? context.l10n.playerUnmute : context.l10n.playerMute,
            onPressed: () {
              if (!muted) _beforeMute = status.volume;
              widget.onChanged(muted ? _beforeMute : 0);
            },
            icon: Icon(
              muted
                  ? Icons.volume_off
                  : status.volume < 50
                  ? Icons.volume_down
                  : Icons.volume_up,
            ),
          ),
          SizedBox(
            width: 100,
            child: Slider(
              focusNode: _sliderFocus,
              max: 100,
              value: status.volume.clamp(0, 100).toDouble(),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      );
    },
  );
}
