import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keyboard/D-pad: when focus enters [child], scrolls the enclosing scrollable so the whole group (e.g. a title
/// with its buttons or cards) is visible, as far as possible while the focused item stays visible.
/// Non-focusable parts of the group would otherwise never be scrolled into view without a pointer.
class RevealOnFocus extends StatelessWidget {
  static const _duration = Duration(milliseconds: 200);

  final Widget child;

  /// Extra space around the group to reveal too (e.g. the list padding above the first group).
  final double margin;

  const RevealOnFocus({super.key, required this.child, this.margin = 16});

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      if (!focused || FocusManager.instance.highlightMode != FocusHighlightMode.traditional) return;
      // After layout and after the traversal's own ensureVisible for the focused item.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _reveal(context);
      });
    },
    child: child,
  );

  void _reveal(BuildContext context) {
    final group = context.findRenderObject();
    final item = FocusManager.instance.primaryFocus?.context?.findRenderObject();
    if (group is! RenderBox || item == null || !group.attached || !item.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(group);
    if (viewport is! RenderViewportBase || viewport.offset is! ScrollPosition) return;
    final position = viewport.offset as ScrollPosition;
    if (!position.hasContentDimensions) return;

    final groupRect = (Offset.zero & group.size).inflate(margin);
    final groupStart = viewport.getOffsetToReveal(group, 0, rect: groupRect).offset;
    final groupEnd = viewport.getOffsetToReveal(group, 1, rect: groupRect).offset;
    final itemStart = viewport.getOffsetToReveal(item, 0).offset;
    final itemEnd = viewport.getOffsetToReveal(item, 1).offset;

    // Fits: minimal scroll to show all of it; taller than the viewport: as close to its start as possible.
    final wanted = groupEnd <= groupStart ? position.pixels.clamp(groupEnd, groupStart) : groupStart;
    final target = wanted
        .clamp(min(itemEnd, itemStart), itemStart)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() > 0.5) {
      position.animateTo(target, duration: _duration, curve: Curves.easeOutCubic);
    }
  }
}
