import 'package:flutter/material.dart';

/// Fades the trailing [width] of [child] to transparent (applies to content overflowing into that area too,
/// because the enclosing list clips at the same edge).
class TrailingFade extends StatelessWidget {
  static const width = 48.0;

  final Widget child;

  const TrailingFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) {
      final fadeStart = bounds.width <= width ? 0.0 : 1 - width / bounds.width;
      return LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, fadeStart, 1],
      ).createShader(bounds, textDirection: Directionality.of(context));
    },
    child: child,
  );
}
