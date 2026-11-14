import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../../domain/player_session.dart';
import '../player_controller.dart';
import '../widgets/player_widgets.dart';

/// Minimal controls for phone/tablet/TV until their dedicated controls (M5.5, M5.6): tap or any arrow shows
/// them; with hidden controls Select/Enter toggles playback; Back leaves the player.
class BasicControls extends ConsumerStatefulWidget {
  final PlayerSession session;

  const BasicControls({super.key, required this.session});

  @override
  ConsumerState<BasicControls> createState() => _BasicControlsState();
}

class _BasicControlsState extends ConsumerState<BasicControls> {
  late final PlayerController _controller;
  late final ControlsVisibility _visibility;
  final _rootFocus = FocusNode(debugLabel: 'playerRoot');
  final _playFocus = FocusNode(debugLabel: 'playerPlay');

  static final _activateKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.mediaPlayPause,
  };
  static final _arrowKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
    _visibility = ControlsVisibility(() => _controller.status)..addListener(_onVisibility);
  }

  @override
  void dispose() {
    _visibility.dispose();
    _rootFocus.dispose();
    _playFocus.dispose();
    super.dispose();
  }

  void _onVisibility() {
    // Hidden buttons must not keep focus: Select would activate them invisibly.
    if (!_visibility.visible && _rootFocus.hasFocus) _rootFocus.requestFocus();
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (!_visibility.visible && widget.session.failure == null) {
      if (_activateKeys.contains(key)) {
        _controller.playOrPause();
        return KeyEventResult.handled;
      }
      if (_arrowKeys.contains(key)) {
        _visibility.show();
        _playFocus.requestFocus();
        return KeyEventResult.handled;
      }
    }
    _visibility.show();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
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
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: _visibility.toggle),
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
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerSeekBar(status: status, onSeek: _controller.seekTo),
                          Row(
                            children: [
                              IconButton(
                                tooltip: context.l10n.playerPrevious,
                                onPressed: session.hasPrevious ? _controller.previous : null,
                                icon: const Icon(Icons.skip_previous),
                              ),
                              PlayPauseButton(
                                status: status,
                                focusNode: _playFocus,
                                onPressed: _controller.playOrPause,
                              ),
                              IconButton(
                                tooltip: context.l10n.playerNext,
                                onPressed: session.hasNext ? _controller.next : null,
                                icon: const Icon(Icons.skip_next),
                              ),
                              const SizedBox(width: 8),
                              PlayerTimeLabel(status: status),
                              const Spacer(),
                              if (session.sources.length > 1)
                                SourceButton(session: session, onSelected: _controller.selectSource),
                              if (session.items.length > 1) PlaylistButton(session: session),
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
    );
  }
}
