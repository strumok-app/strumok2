import 'package:flutter/material.dart';

/// Focus marker for list cards: a short pill just outside the card's leading edge.
/// Needs ≥ 8 px of free space to the left.
class FocusAccentBar extends StatelessWidget {
  static const width = 4.0;
  static const offset = 8.0;

  final bool focused;
  final Widget child;

  const FocusAccentBar({super.key, required this.focused, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      PositionedDirectional(
        start: -offset,
        top: 0,
        bottom: 0,
        width: width,
        child: IgnorePointer(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: width,
              height: focused ? 32 : 0,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: const BorderRadius.all(Radius.circular(width / 2)),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
