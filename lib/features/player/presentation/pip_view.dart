import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization.dart';
import '../data/pip/pip.dart';
import '../data/video_backend.dart';
import '../domain/player_session.dart';
import 'player_controller.dart';
import 'widgets/compact_player_controls.dart';
import 'widgets/player_widgets.dart';
import 'widgets/subtitle_overlay.dart';

/// Keeps platform PiP in sync with the session and plays platform PiP actions (spec-06 §6.10).
class PipBinding extends ConsumerStatefulWidget {
  final PlayerSession? session;
  final ValueListenable<PlaybackStatus> status;
  final Widget child;

  const PipBinding({super.key, required this.session, required this.status, required this.child});

  @override
  ConsumerState<PipBinding> createState() => _PipBindingState();
}

class _PipBindingState extends ConsumerState<PipBinding> {
  late final Pip _pip;
  late final PlayerController _controller;
  late final StreamSubscription<PipAction> _actions;
  PipPlayback? _last;

  @override
  void initState() {
    super.initState();
    _pip = ref.read(pipProvider);
    _controller = ref.read(playerControllerProvider.notifier);
    _actions = _pip.actions.listen(_onAction);
    widget.status.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(PipBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      oldWidget.status.removeListener(_sync);
      widget.status.addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    unawaited(_actions.cancel());
    widget.status.removeListener(_sync);
    // No auto-enter with a stale playing state.
    unawaited(_pip.updatePlayback(const PipPlayback()));
    super.dispose();
  }

  void _onAction(PipAction action) => unawaited(switch (action) {
    PipAction.playPause => _controller.playOrPause(),
    PipAction.next => _controller.next(),
    PipAction.prev => _controller.previous(),
    PipAction.dismissed => _controller.pause(),
  });

  void _sync() {
    final session = widget.session;
    final status = widget.status.value;
    final playback = PipPlayback(
      isPlaying: status.playing,
      hasPrev: session?.hasPrevious ?? false,
      hasNext: session?.hasNext ?? false,
      showSkipButtons: (session?.items.length ?? 0) > 1,
      aspectRatio: status.aspectRatio ?? PipPlayback.defaultAspectRatio,
    );
    if (playback == _last) return;
    _last = playback;
    unawaited(_pip.updatePlayback(playback));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Enters PiP; hidden where PiP is not supported (TV).
class PipButton extends ConsumerWidget {
  final double? iconSize;

  const PipButton({super.key, this.iconSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pip = ref.watch(pipProvider);
    if (!pip.isSupported) return const SizedBox.shrink();
    return IconButton(
      key: const Key('pipButton'),
      tooltip: context.l10n.playerPip,
      iconSize: iconSize,
      onPressed: () => unawaited(pip.enter()),
      icon: const Icon(Icons.picture_in_picture_alt),
    );
  }
}

/// Shown over the video while PiP is active: no player controls, subtitles scaled to the window. Android draws
/// its own PiP controls and passes no input, so only the desktop compact window is [interactive].
class PipView extends ConsumerWidget {
  final PlayerSession session;
  final bool interactive;

  const PipView({super.key, required this.session, required this.interactive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pip = ref.read(pipProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final passive = [
      const ScaledSubtitleOverlay(),
      PlayerBufferingIndicator(session: session, status: controller.status),
    ];
    if (!interactive) {
      return IgnorePointer(
        child: Stack(fit: StackFit.expand, children: passive),
      );
    }

    return GestureDetector(
      key: const Key('pipSurface'),
      onPanStart: (_) => unawaited(pip.startWindowDrag()),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ...passive,
          CompactPlayerControls(
            session: session,
            keyboard: true,
            expandLabel: context.l10n.playerExitPip,
            onExpand: () => unawaited(pip.exit()),
            closeLabel: context.l10n.playerCloseApp,
            // SPEC: legacy closes the app from the compact window (it has no title bar); progress is saved first.
            onClose: () => unawaited(controller.close().then((_) => pip.closeApp())),
          ),
        ],
      ),
    );
  }
}
