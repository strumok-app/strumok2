import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reveal_on_focus.dart';

/// Icon button at the end of a row header.
final class RowAction {
  final Key? key;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const RowAction({this.key, required this.icon, required this.tooltip, required this.onPressed});
}

/// Header (title, muted label and trailing [actions]) over a horizontal row [body], revealed together on focus.
///
/// D-pad/keyboard: directional traversal never reaches the actions (they sit at the far right, out of the band of
/// the focused card), so they are skipped by it and handled here instead: ↑ in the body focuses the first action,
/// ←/→ move between actions, ↓ returns to the last focused body item and ↑ continues above the row from it.
class ContentRowFrame extends StatefulWidget {
  final String title;
  final String? label;
  final List<RowAction> actions;
  final Widget body;

  const ContentRowFrame({super.key, required this.title, this.label, this.actions = const [], required this.body});

  @override
  State<ContentRowFrame> createState() => _ContentRowFrameState();
}

class _ContentRowFrameState extends State<ContentRowFrame> {
  final _body = FocusNode(debugLabel: 'rowBody', canRequestFocus: false, skipTraversal: true);
  final _actionNodes = <FocusNode>[];
  FocusNode? _lastInBody;

  @override
  void initState() {
    super.initState();
    _syncActionNodes();
  }

  @override
  void didUpdateWidget(ContentRowFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActionNodes();
  }

  @override
  void dispose() {
    _body.dispose();
    for (final node in _actionNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncActionNodes() {
    while (_actionNodes.length < widget.actions.length) {
      _actionNodes.add(FocusNode(debugLabel: 'rowAction', skipTraversal: true));
    }
    while (_actionNodes.length > widget.actions.length) {
      _actionNodes.removeLast().dispose();
    }
  }

  static bool _isPress(KeyEvent event) => event is KeyDownEvent || event is KeyRepeatEvent;

  KeyEventResult _onBodyKey(FocusNode node, KeyEvent event) {
    if (_actionNodes.isEmpty || !_isPress(event) || event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    _lastInBody = FocusManager.instance.primaryFocus;
    _actionNodes.first.requestFocus();
    return KeyEventResult.handled;
  }

  KeyEventResult _onHeaderKey(FocusNode node, KeyEvent event) {
    final index = _actionNodes.indexWhere((n) => n.hasPrimaryFocus);
    if (index < 0 || !_isPress(event)) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        if (index > 0) _actionNodes[index - 1].requestFocus();
      case LogicalKeyboardKey.arrowRight:
        if (index < _actionNodes.length - 1) _actionNodes[index + 1].requestFocus();
      case LogicalKeyboardKey.arrowDown:
        final target = _bodyTarget();
        if (target == null) return KeyEventResult.ignored;
        target.requestFocus();
      case LogicalKeyboardKey.arrowUp:
        final origin = _bodyTarget();
        if (origin == null) return KeyEventResult.ignored;
        // Traverse up as if from the row itself, so focus lands above the remembered card, not above the header end.
        origin.requestFocus();
        if (!origin.focusInDirection(TraversalDirection.up)) _actionNodes[index].requestFocus();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  FocusNode? _bodyTarget() {
    final last = _lastInBody;
    if (last != null && last.context != null && last.canRequestFocus && last.ancestors.contains(_body)) return last;
    return _body.traversalDescendants.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = widget.actions;
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.title),
          if (widget.label case final label?)
            TextSpan(
              text: '  $label',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      style: theme.textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return RevealOnFocus(
      margin: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actions.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: title)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _onHeaderKey,
                child: Row(
                  children: [
                    Expanded(child: title),
                    for (final (index, action) in actions.indexed)
                      IconButton(
                        key: action.key,
                        focusNode: _actionNodes[index],
                        visualDensity: VisualDensity.compact,
                        tooltip: action.tooltip,
                        icon: Icon(action.icon),
                        onPressed: action.onPressed,
                      ),
                  ],
                ),
              ),
            ),
          Focus(focusNode: _body, onKeyEvent: _onBodyKey, child: widget.body),
        ],
      ),
    );
  }
}
