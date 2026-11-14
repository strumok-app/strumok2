import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// D-pad behaviour of a native Android single-line `EditText` for a wrapped single-line text field:
/// ↑/↓ always move focus out of the field; ←/→ move the caret and only leave the field from its start/end,
/// on a fresh key press (holding the key stops at the boundary). Without this a focused field traps D-pad focus.
class TextFieldArrowEscape extends StatelessWidget {
  final TextEditingController controller;
  final Widget child;

  const TextFieldArrowEscape({super.key, required this.controller, required this.child});

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed || keyboard.isAltPressed || keyboard.isControlPressed || keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final value = controller.value;
    final selection = value.selection;
    final caret = selection.isValid && selection.isCollapsed && !value.composing.isValid ? selection.baseOffset : null;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft when caret == 0 || value.text.isEmpty => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight when caret == value.text.length || value.text.isEmpty => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;

    // Ignore keys from other focusables inside the field (e.g. the clear button in the decoration).
    final field = FocusManager.instance.primaryFocus;
    if (field?.context?.findAncestorStateOfType<EditableTextState>() == null) return KeyEventResult.ignored;
    return field!.focusInDirection(direction) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: child);
}
