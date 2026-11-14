import 'package:flutter/material.dart';

const _focusDuration = Duration(milliseconds: 120);

/// TV/keyboard focus for image-filled surfaces (posters, avatars): a ring drawn *outside* [child] with a
/// transparent gap, plus a soft outer glow, so the content itself is never covered.
/// Pass [borderRadius] for rounded rectangles; null draws a circle.
class FocusRing extends StatelessWidget {
  static const gap = 3.0;
  static const width = 2.5;
  static const _outset = gap + width;

  final bool focused;
  final BorderRadius? borderRadius;
  final Widget child;

  const FocusRing({super.key, required this.focused, required this.child, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final radius = borderRadius;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          left: -_outset,
          top: -_outset,
          right: -_outset,
          bottom: -_outset,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: _focusDuration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: radius == null ? null : radius + BorderRadius.circular(_outset),
                  border: Border.all(color: color, width: width),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14, blurStyle: BlurStyle.outer),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Focus marker for list cards: a short pill just outside the card's leading edge. Pair it with a tonal
/// background on the card; together they don't rely on colour alone. Needs ≥ 8 px of free space to the left.
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
              duration: _focusDuration,
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
