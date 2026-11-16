import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization.dart';
import '../../../../../core/platform/device_levels.dart';
import '../../../domain/player_session.dart';
import '../../player_controller.dart';
import '../../widgets/player_widgets.dart';

enum _Level { brightness, volume }

// Center buttons float over the video: a dark disc keeps them readable on bright frames.
const _centerButtonStyle = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(Color(0x80000000)),
  padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
  shape: WidgetStatePropertyAll(CircleBorder()),
);

/// Touch controls for phone/tablet (spec-06 §7): tap toggles the overlay, double-tap a half to seek ±10 s
/// (accumulating), horizontal swipe to seek, vertical swipe on the left/right half for brightness/volume, and a lock
/// that disables all of it. Forces landscape + immersive mode while shown.
class MobileControls extends ConsumerStatefulWidget {
  final PlayerSession session;

  const MobileControls({super.key, required this.session});

  @override
  ConsumerState<MobileControls> createState() => _MobileControlsState();
}

class _MobileControlsState extends ConsumerState<MobileControls> {
  static const _seekStep = 10;
  static const _indicatorTimeout = Duration(milliseconds: 800);

  /// Seek range of a swipe across the full screen width.
  static const _swipeRange = Duration(seconds: 120);

  late final PlayerController _controller;
  late final ControlsVisibility _visibility;
  late final BrightnessControl _brightness;
  late final VolumeControl _volume;

  bool _locked = false;

  Offset? _doubleTapAt;
  bool? _seekForward;
  int _seekSeconds = 0;
  Timer? _seekTimer;

  _Level? _level;
  double _levelValue = 0;
  bool _levelReady = false;
  Timer? _levelTimer;

  Duration? _swipeFrom;
  Duration? _swipeTo;
  double _swipeDx = 0;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
    _brightness = ref.read(brightnessControlProvider);
    _volume = ref.read(volumeControlProvider);
    _visibility = ControlsVisibility(() => _controller.status)..addListener(_rebuild);
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  void dispose() {
    _seekTimer?.cancel();
    _levelTimer?.cancel();
    _visibility.dispose();
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(_brightness.reset());
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onDoubleTap() {
    final at = _doubleTapAt;
    final size = context.size;
    if (_locked || at == null || size == null) return;
    final forward = at.dx >= size.width / 2;
    setState(() {
      _seekSeconds = _seekForward == forward ? _seekSeconds + _seekStep : _seekStep;
      _seekForward = forward;
    });
    unawaited(_controller.seekBy(Duration(seconds: forward ? _seekStep : -_seekStep)));
    _seekTimer?.cancel();
    _seekTimer = Timer(_indicatorTimeout, () => setState(() => _seekForward = null));
  }

  Future<void> _onDragStart(DragStartDetails details) async {
    final size = context.size;
    if (_locked || size == null) return;
    final level = details.localPosition.dx < size.width / 2 ? _Level.brightness : _Level.volume;
    _levelTimer?.cancel();
    setState(() {
      _level = level;
      _levelReady = false;
    });
    final value = await (level == _Level.brightness ? _brightness.get() : _volume.get());
    if (!mounted || _level != level) return;
    setState(() {
      _levelValue = value.clamp(0, 1);
      _levelReady = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final size = context.size;
    final level = _level;
    if (level == null || !_levelReady || size == null) return;
    // A drag over ~60% of the height covers the whole range.
    final value = (_levelValue - details.delta.dy / (size.height * 0.6)).clamp(0.0, 1.0);
    setState(() => _levelValue = value);
    unawaited(level == _Level.brightness ? _brightness.set(value) : _volume.set(value));
  }

  void _onDragEnd([Object? _]) {
    _levelTimer?.cancel();
    _levelTimer = Timer(_indicatorTimeout, () => setState(() => _level = null));
  }

  void _onSwipeStart(DragStartDetails details) {
    final status = _controller.status.value;
    if (_locked || status.duration <= Duration.zero) return;
    setState(() {
      _swipeFrom = status.position;
      _swipeTo = status.position;
      _swipeDx = 0;
    });
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    final from = _swipeFrom;
    final width = context.size?.width;
    if (from == null || width == null || width <= 0) return;
    _swipeDx += details.delta.dx;
    final offset = Duration(seconds: (_swipeDx / width * _swipeRange.inSeconds).round());
    final duration = _controller.status.value.duration;
    var to = from + offset;
    if (to < Duration.zero) to = Duration.zero;
    if (to > duration) to = duration;
    setState(() => _swipeTo = to);
  }

  void _onSwipeEnd([Object? _]) {
    final to = _swipeTo;
    if (to != null && to != _swipeFrom) unawaited(_controller.seekTo(to));
    setState(() {
      _swipeFrom = null;
      _swipeTo = null;
    });
  }

  /// Seek bar drags share the swipe indicator; the bar seeks by itself.
  void _onBarDragTarget(Duration? to) {
    _visibility.show();
    setState(() {
      _swipeFrom = to == null ? null : (_swipeFrom ?? _controller.status.value.position);
      _swipeTo = to;
    });
  }

  void _setLocked(bool locked) {
    setState(() => _locked = locked);
    _visibility.show();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final status = _controller.status;
    final visible = _visibility.visible || session.failure != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: const Key('playerGestures'),
          behavior: HitTestBehavior.opaque,
          onTap: _visibility.toggle,
          onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
          onDoubleTap: _onDoubleTap,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _onDragEnd,
          onHorizontalDragStart: _onSwipeStart,
          onHorizontalDragUpdate: _onSwipeUpdate,
          onHorizontalDragEnd: _onSwipeEnd,
          onHorizontalDragCancel: _onSwipeEnd,
        ),
        PlayerBufferingIndicator(session: session, status: status),
        if (_seekForward case final forward?) _SeekIndicator(forward: forward, seconds: _seekSeconds),
        if (_level case final level? when _levelReady) _LevelIndicator(level: level, value: _levelValue),
        if ((_swipeFrom, _swipeTo) case (final from?, final to?)) _SwipeIndicator(from: from, to: to),
        IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: _locked ? _LockedOverlay(onUnlock: () => _setLocked(false)) : _overlay(session),
          ),
        ),
        if (session.failure != null) PlayerFailureView(session: session),
      ],
    );
  }

  Widget _overlay(PlayerSession session) {
    final l10n = context.l10n;
    final status = _controller.status;
    // Center buttons sit at the exact screen center, whatever the bars' heights.
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ControlsScrim(
            top: true,
            child: PlayerTopBar(
              session: session,
              actions: [
                IconButton(
                  key: const Key('lockButton'),
                  tooltip: l10n.playerLock,
                  onPressed: () => _setLocked(true),
                  icon: const Icon(Icons.lock_open),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 32,
            children: [
              IconButton(
                iconSize: 36,
                style: _centerButtonStyle,
                tooltip: l10n.playerPrevious,
                onPressed: session.hasPrevious ? _controller.previous : null,
                icon: const Icon(Icons.skip_previous),
              ),
              PlayPauseButton(
                status: status,
                iconSize: 56,
                style: _centerButtonStyle,
                onPressed: _controller.playOrPause,
              ),
              IconButton(
                iconSize: 36,
                style: _centerButtonStyle,
                tooltip: l10n.playerNext,
                onPressed: session.hasNext ? _controller.next : null,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
            // The row overlaps the seek bar's touch area; touches between its buttons reach the bar.
            child: Stack(
              children: [
                // Flush with the screen's bottom and side edges.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PlayerSeekBar(
                    status: status,
                    onSeek: _controller.seekTo,
                    onDragTarget: _onBarDragTarget,
                    style: SeekBarStyle.edge,
                  ),
                ),
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, PlayerSeekBar.edgeTrackHeight + 2),
                    child: Row(
                      children: [
                        IgnorePointer(child: PlayerTimeLabel(status: status)),
                        const Spacer(),
                        if (session.sources.length > 1)
                          SourceButton(session: session, onSelected: _controller.selectSource),
                        if (session.items.length > 1) PlaylistButton(session: session),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  final VoidCallback onUnlock;

  const _LockedOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IconButton.filledTonal(
          key: const Key('unlockButton'),
          iconSize: 32,
          tooltip: context.l10n.playerUnlock,
          onPressed: onUnlock,
          icon: const Icon(Icons.lock),
        ),
      ),
    ),
  );
}

/// Full-height third of the screen on the tapped side, darkened towards that edge, with the accumulated offset.
class _SeekIndicator extends StatelessWidget {
  final bool forward;
  final int seconds;

  const _SeekIndicator({required this.forward, required this.seconds});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 1 / 3,
        heightFactor: 1,
        child: DecoratedBox(
          key: const Key('seekIndicator'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: forward ? Alignment.centerRight : Alignment.centerLeft,
              end: forward ? Alignment.centerLeft : Alignment.centerRight,
              colors: const [Color(0x99000000), Color(0x00000000)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(forward ? Icons.fast_forward : Icons.fast_rewind, size: 32),
                Text(forward ? context.l10n.playerSeekForward(seconds) : context.l10n.playerSeekBackward(seconds)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Target time and offset of a horizontal swipe.
class _SwipeIndicator extends StatelessWidget {
  final Duration from;
  final Duration to;

  const _SwipeIndicator({required this.from, required this.to});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      // Between the center buttons and the bottom row.
      alignment: const Alignment(0, 0.4),
      child: SeekTargetLabel(key: const Key('swipeSeekIndicator'), from: from, to: to),
    ),
  );
}

/// Vertical level bar with an icon, on the side being dragged.
class _LevelIndicator extends StatelessWidget {
  final _Level level;
  final double value;

  const _LevelIndicator({required this.level, required this.value});

  @override
  Widget build(BuildContext context) {
    final brightness = level == _Level.brightness;
    final icon = brightness
        ? (value < 0.5 ? Icons.brightness_low : Icons.brightness_high)
        : (value == 0 ? Icons.volume_off : (value < 0.5 ? Icons.volume_down : Icons.volume_up));
    return IgnorePointer(
      child: Align(
        alignment: brightness ? const Alignment(-0.8, 0) : const Alignment(0.8, 0),
        child: Semantics(
          label: brightness ? context.l10n.playerBrightness : context.l10n.playerVolume,
          value: '${(value * 100).round()}%',
          child: _Bubble(
            key: Key(brightness ? 'brightnessIndicator' : 'volumeIndicator'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(icon, size: 28),
                SizedBox(
                  height: 120,
                  width: 6,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: LinearProgressIndicator(value: value, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Widget child;

  const _Bubble({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: Color(0x99000000), borderRadius: BorderRadius.all(Radius.circular(16))),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}
