import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization.dart';
import '../../../data/video_backend.dart';
import '../../../domain/player_session.dart';
import '../../player_controller.dart';
import '../../widgets/player_panels.dart';
import '../../widgets/player_widgets.dart';
import '../../widgets/subtitle_overlay.dart';

/// D-pad controls for Android TV (spec-06 §6.8). While nothing in the overlay is focused: ←/→ accumulate a seek
/// preview committed after 500 ms, OK plays/pauses, ↑/↓ open the controls on Play. Back hides the controls first.
class TvControls extends ConsumerStatefulWidget {
  final PlayerSession session;

  const TvControls({super.key, required this.session});

  @override
  ConsumerState<TvControls> createState() => _TvControlsState();
}

class _TvControlsState extends ConsumerState<TvControls> {
  static const _seekStep = Duration(seconds: 10);
  static const _seekDebounce = Duration(milliseconds: 500);

  static final _activateKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };
  static final _arrowKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  late final PlayerController _controller;
  late final ControlsVisibility _visibility;
  // Not a traversal target: arrows past the last button would land on the full-screen root.
  final _rootFocus = FocusNode(debugLabel: 'tvPlayerRoot', skipTraversal: true);
  final _overlayFocus = FocusNode(debugLabel: 'tvPlayerOverlay', canRequestFocus: false, skipTraversal: true);
  final _playFocus = FocusNode(debugLabel: 'tvPlayerPlay');
  final _seekBarFocus = FocusNode(debugLabel: 'tvPlayerSeekBar');
  final _retryFocus = FocusNode(debugLabel: 'tvPlayerRetry');

  Duration? _seekFrom;
  Duration? _seekTo;
  Timer? _seekTimer;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
    _visibility = ControlsVisibility(() => _controller.status)..addListener(_onVisibility);
    if (widget.session.failure != null) _focusRetry();
  }

  @override
  void didUpdateWidget(TvControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.failure == null && widget.session.failure != null) _focusRetry();
  }

  @override
  void dispose() {
    _seekTimer?.cancel();
    _visibility.dispose();
    _rootFocus.dispose();
    _overlayFocus.dispose();
    _playFocus.dispose();
    _seekBarFocus.dispose();
    _retryFocus.dispose();
    super.dispose();
  }

  void _onVisibility() {
    if (!_visibility.visible) {
      // A dialog or panel opened from the controls holds focus; keep them so focus can return to its button.
      if (!_rootFocus.hasFocus) return _visibility.show();
      // Hidden buttons must not keep focus: OK would activate them invisibly.
      if (_overlayFocus.hasFocus) _rootFocus.requestFocus();
    }
    setState(() {});
  }

  void _focusRetry() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _retryFocus.requestFocus();
  });

  void _focusPlay() {
    final wasVisible = _visibility.visible;
    _visibility.show();
    if (wasVisible) {
      _playFocus.requestFocus();
    } else {
      // The overlay accepts focus only after it is rebuilt as visible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playFocus.requestFocus();
      });
    }
  }

  void _stepSeek(int direction) {
    final status = _controller.status.value;
    if (status.duration <= Duration.zero) return;
    final from = _seekFrom ?? status.position;
    var to = (_seekTo ?? from) + _seekStep * direction;
    if (to < Duration.zero) to = Duration.zero;
    if (to > status.duration) to = status.duration;
    _seekTimer?.cancel();
    _seekTimer = Timer(_seekDebounce, _commitSeek);
    setState(() {
      _seekFrom = from;
      _seekTo = to;
    });
  }

  void _commitSeek() {
    final from = _seekFrom, to = _seekTo;
    setState(() {
      _seekFrom = null;
      _seekTo = null;
    });
    if (to != null && to != from) unawaited(_controller.seekTo(to));
  }

  bool _run(void Function() action) {
    action();
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final failed = widget.session.failure != null;

    final media = switch (key) {
      LogicalKeyboardKey.mediaPlayPause when !repeat => _run(() => unawaited(_controller.playOrPause())),
      LogicalKeyboardKey.mediaPlay => _run(() => unawaited(_controller.play())),
      LogicalKeyboardKey.mediaPause => _run(() => unawaited(_controller.pause())),
      LogicalKeyboardKey.mediaTrackNext when !repeat => _run(() => unawaited(_controller.next())),
      LogicalKeyboardKey.mediaTrackPrevious when !repeat => _run(() => unawaited(_controller.previous())),
      LogicalKeyboardKey.mediaFastForward => _run(() => _stepSeek(1)),
      LogicalKeyboardKey.mediaRewind => _run(() => _stepSeek(-1)),
      _ => false,
    };
    if (media) return KeyEventResult.handled;

    // Unhandled Back leaves the player (app-level Escape action / Android system back).
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (failed || !_visibility.visible) return KeyEventResult.ignored;
      if (!repeat) _visibility.hide();
      return KeyEventResult.handled;
    }

    // Focus is inside the overlay or the failure view: regular traversal and activation.
    if (!node.hasPrimaryFocus) {
      _visibility.show();
      return KeyEventResult.ignored;
    }
    if (failed) {
      if (!_arrowKeys.contains(key)) return KeyEventResult.ignored;
      _retryFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return switch (key) {
          _ when _activateKeys.contains(key) => repeat || _run(() => unawaited(_controller.playOrPause())),
          LogicalKeyboardKey.arrowLeft => _run(() => _stepSeek(-1)),
          LogicalKeyboardKey.arrowRight => _run(() => _stepSeek(1)),
          LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowDown => _run(_focusPlay),
          _ => false,
        }
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  KeyEventResult _onSeekBarKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final handled = switch (key) {
      LogicalKeyboardKey.arrowLeft => _run(() => _stepSeek(-1)),
      LogicalKeyboardKey.arrowRight => _run(() => _stepSeek(1)),
      // The bar spans all buttons; directional traversal would pick an arbitrary one.
      LogicalKeyboardKey.arrowDown => _run(_playFocus.requestFocus),
      _ when _activateKeys.contains(key) => event is KeyRepeatEvent || _run(() => unawaited(_controller.playOrPause())),
      _ => false,
    };
    if (!handled) return KeyEventResult.ignored;
    _visibility.show();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    final status = _controller.status;
    final visible = _visibility.visible || session.failure != null;

    return Focus(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlayerBufferingIndicator(session: session, status: status),
          SubtitleOverlay(bottom: visible ? 150 : 48),
          if ((_seekFrom, _seekTo) case (final from?, final to?)) ...[
            Align(
              alignment: const Alignment(0, 0.4),
              child: SeekTargetLabel(key: const Key('tvSeekPreview'), from: from, to: to),
            ),
            if (!visible)
              Positioned(
                left: 48,
                right: 48,
                bottom: 32,
                child: _SeekBarView(status: status, target: to, focused: false),
              ),
          ],
          IgnorePointer(
            ignoring: !visible,
            child: ExcludeFocus(
              excluding: !visible,
              child: Focus(
                focusNode: _overlayFocus,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      ControlsScrim(
                        top: true,
                        child: PlayerTopBar(
                          session: session,
                          back: false,
                          padding: const EdgeInsets.fromLTRB(48, 24, 48, 0),
                        ),
                      ),
                      const Spacer(),
                      ControlsScrim(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(48, 0, 48, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Focus(
                                key: const Key('tvSeekBar'),
                                focusNode: _seekBarFocus,
                                onKeyEvent: _onSeekBarKey,
                                child: ListenableBuilder(
                                  listenable: _seekBarFocus,
                                  builder: (context, _) =>
                                      _SeekBarView(status: status, target: _seekTo, focused: _seekBarFocus.hasFocus),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder(
                                valueListenable: _controller.tracks,
                                builder: (context, tracks, _) => Row(
                                  spacing: 8,
                                  children: [
                                    _TvButton(
                                      icon: Icons.skip_previous,
                                      label: l10n.playerPrevious,
                                      onPressed: session.hasPrevious ? _controller.previous : null,
                                    ),
                                    ValueListenableBuilder(
                                      valueListenable: status,
                                      builder: (context, status, _) => _TvButton(
                                        key: const Key('playPauseButton'),
                                        focusNode: _playFocus,
                                        icon: status.playing ? Icons.pause : Icons.play_arrow,
                                        label: status.playing ? l10n.playerPause : l10n.playerPlay,
                                        onPressed: _controller.playOrPause,
                                      ),
                                    ),
                                    _TvButton(
                                      icon: Icons.skip_next,
                                      label: l10n.playerNext,
                                      onPressed: session.hasNext ? _controller.next : null,
                                    ),
                                    const SizedBox(width: 8),
                                    PlayerTimeLabel(status: status),
                                    const Spacer(),
                                    if (session.subtitles.isNotEmpty)
                                      _TvButton(
                                        key: const Key('subtitlesButton'),
                                        icon: subtitlesToggleIcon(on: session.subtitleIndex != null),
                                        label: session.subtitleIndex != null
                                            ? l10n.playerHideSubtitles
                                            : l10n.playerShowSubtitles,
                                        onPressed: () => unawaited(_controller.toggleSubtitles()),
                                      ),
                                    if (session.sources.length > 1)
                                      _TvButton(
                                        icon: Icons.dns_outlined,
                                        label: l10n.playerSource,
                                        onPressed: () => showSourceSelector(context, session, _controller.selectSource),
                                      ),
                                    _TvButton(
                                      key: const Key('settingsButton'),
                                      icon: Icons.settings_outlined,
                                      label: l10n.playerSettings,
                                      onPressed: () => showPlayerSettings(context),
                                    ),
                                    if (session.items.length > 1)
                                      _TvButton(
                                        icon: Icons.playlist_play,
                                        label: l10n.detailsEpisodes,
                                        onPressed: () => showPlaylistPanel(context, session),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (session.failure != null) PlayerFailureView(session: session, retryFocus: _retryFocus),
        ],
      ),
    );
  }
}

/// Icon button that expands into a labeled pill while focused; inverted colors read well from the couch.
class _TvButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  const _TvButton({super.key, required this.icon, required this.label, required this.onPressed, this.focusNode});

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  static final _style = ButtonStyle(
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
    minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused) ? Colors.white : Colors.transparent,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? Colors.white38
          : states.contains(WidgetState.focused)
          ? Colors.black
          : Colors.white,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );

  bool _focused = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.label,
    child: TextButton(
      focusNode: widget.focusNode,
      style: _style,
      onPressed: widget.onPressed,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 32),
            if (_focused)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Played / buffered track; focused: thicker with a large thumb. A pending seek target shows as a lighter span.
class _SeekBarView extends StatelessWidget {
  final ValueListenable<PlaybackStatus> status;
  final Duration? target;
  final bool focused;

  const _SeekBarView({required this.status, required this.target, required this.focused});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: status,
      builder: (context, status, _) {
        final duration = status.duration.inMilliseconds;
        double fraction(Duration d) => duration <= 0 ? 0 : (d.inMilliseconds / duration).clamp(0.0, 1.0);
        return Semantics(
          slider: true,
          focused: focused,
          value: '${formatPlaybackTime(target ?? status.position)} / ${formatPlaybackTime(status.duration)}',
          child: SizedBox(
            height: 32,
            width: double.infinity,
            child: CustomPaint(
              painter: _SeekBarPainter(
                position: fraction(status.position),
                buffered: fraction(status.buffered),
                target: target == null ? null : fraction(target!),
                focused: focused,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  final double position;
  final double buffered;
  final double? target;
  final bool focused;
  final Color color;

  const _SeekBarPainter({
    required this.position,
    required this.buffered,
    required this.target,
    required this.focused,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final height = focused ? 8.0 : 4.0;
    final top = (size.height - height) / 2;
    void span(double from, double to, Color color) {
      if (to <= from) return;
      canvas.drawRRect(
        RRect.fromLTRBR(size.width * from, top, size.width * to, top + height, Radius.circular(height / 2)),
        Paint()..color = color,
      );
    }

    span(0, 1, Colors.white24);
    span(0, buffered, Colors.white38);
    span(0, position, color);
    if (target case final target?) span(math.min(position, target), math.max(position, target), Colors.white70);
    if (focused || target != null) {
      canvas.drawCircle(
        Offset(size.width * (target ?? position), size.height / 2),
        focused ? 12 : 6,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.position != position ||
      old.buffered != buffered ||
      old.target != target ||
      old.focused != focused ||
      old.color != color;
}
