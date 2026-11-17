import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../../domain/player_session.dart';
import '../player_controller.dart';
import 'player_widgets.dart';

/// Mouse controls of a small video window: the desktop PiP window and the desktop floating player. Prev / play /
/// next in the center, expand top-left, close top-right, progress at the bottom; shown on hover or tap, hidden
/// after 2 s without movement. No tooltips: their overlay portals break semantics when the controls fade out
/// (`!child.attached` while flushing semantics).
class CompactPlayerControls extends ConsumerStatefulWidget {
  static const expandKey = Key('compactExpandButton');
  static const closeKey = Key('compactCloseButton');

  final PlayerSession session;
  final String expandLabel;
  final VoidCallback onExpand;
  final String closeLabel;
  final VoidCallback onClose;

  /// Takes keyboard focus: Space plays/pauses, Escape expands.
  final bool keyboard;

  const CompactPlayerControls({
    super.key,
    required this.session,
    required this.expandLabel,
    required this.onExpand,
    required this.closeLabel,
    required this.onClose,
    this.keyboard = false,
  });

  @override
  ConsumerState<CompactPlayerControls> createState() => _CompactPlayerControlsState();
}

class _CompactPlayerControlsState extends ConsumerState<CompactPlayerControls> {
  static const _hideDelay = Duration(seconds: 2);

  late final PlayerController _controller;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _show() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, _hide);
    if (!_visible) setState(() => _visible = true);
  }

  void _hide() {
    _hideTimer?.cancel();
    if (mounted && _visible) setState(() => _visible = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space || LogicalKeyboardKey.mediaPlayPause:
        unawaited(_controller.playOrPause());
        _show();
      case LogicalKeyboardKey.escape:
        widget.onExpand();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    final status = _controller.status;
    final skip = session.items.length > 1;

    final controls = MouseRegion(
      onEnter: (_) => _show(),
      onHover: (_) => _show(),
      onExit: (_) => _hide(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _show,
        child: IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: ColoredBox(
              color: Colors.black45,
              child: Stack(
                children: [
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        if (skip)
                          IconButton(
                            iconSize: 32,
                            onPressed: session.hasPrevious ? _controller.previous : null,
                            icon: Icon(Icons.skip_previous, semanticLabel: l10n.playerPrevious),
                          ),
                        PlayPauseButton(
                          status: status,
                          iconSize: 48,
                          tooltip: false,
                          onPressed: _controller.playOrPause,
                        ),
                        if (skip)
                          IconButton(
                            iconSize: 32,
                            onPressed: session.hasNext ? _controller.next : null,
                            icon: Icon(Icons.skip_next, semanticLabel: l10n.playerNext),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      key: CompactPlayerControls.expandKey,
                      onPressed: widget.onExpand,
                      icon: Icon(Icons.open_in_full, semanticLabel: widget.expandLabel),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      key: CompactPlayerControls.closeKey,
                      onPressed: widget.onClose,
                      icon: Icon(Icons.close, semanticLabel: widget.closeLabel),
                    ),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, child: PlaybackProgressLine(status: status)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return widget.keyboard ? Focus(autofocus: true, onKeyEvent: _onKey, child: controls) : controls;
  }
}
