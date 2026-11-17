import 'dart:math';
import 'dart:ui';

/// Corner the floating player snaps to (spec-06 §6.9).
enum FloatingCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Top-left of a [player] box in [corner] of [area], keeping [horizontal] / [vertical] distance from the edges.
Offset floatingCornerOffset(
  FloatingCorner corner, {
  required Size area,
  required Size player,
  required double horizontal,
  required double vertical,
}) {
  final (minX, maxX) = floatingRangeX(area: area, player: player, horizontal: horizontal);
  final (minY, maxY) = floatingRangeY(area: area, player: player, vertical: vertical);
  return switch (corner) {
    FloatingCorner.topLeft => Offset(minX, minY),
    FloatingCorner.topRight => Offset(maxX, minY),
    FloatingCorner.bottomLeft => Offset(minX, maxY),
    FloatingCorner.bottomRight => Offset(maxX, maxY),
  };
}

(double, double) floatingRangeX({required Size area, required Size player, required double horizontal}) =>
    (horizontal, max(horizontal, area.width - player.width - horizontal));

(double, double) floatingRangeY({required Size area, required Size player, required double vertical}) =>
    (vertical, max(vertical, area.height - player.height - vertical));

/// The corner of the quarter of [area] that holds the player's [center].
FloatingCorner nearestFloatingCorner(Offset center, Size area) {
  final left = center.dx < area.width / 2;
  final top = center.dy < area.height / 2;
  return switch ((left, top)) {
    (true, true) => FloatingCorner.topLeft,
    (false, true) => FloatingCorner.topRight,
    (true, false) => FloatingCorner.bottomLeft,
    (false, false) => FloatingCorner.bottomRight,
  };
}
