import 'dart:math';
import 'dart:typed_data';

/// Pixel rectangle `[left, right) × [top, bottom)`.
final class CropRect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const CropRect(this.left, this.top, this.right, this.bottom);

  int get width => right - left;
  int get height => bottom - top;

  /// Maps bounds found on a downscaled copy back to the original image, widened by one sampled pixel per side so
  /// content blended into a border sample is never cut.
  CropRect scale({required int fromWidth, required int fromHeight, required int toWidth, required int toHeight}) {
    final sx = toWidth / fromWidth, sy = toHeight / fromHeight;
    return CropRect(
      max(0, ((left - 1) * sx).floor()),
      max(0, ((top - 1) * sy).floor()),
      min(toWidth, ((right + 1) * sx).ceil()),
      min(toHeight, ((bottom + 1) * sy).ceil()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CropRect && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'CropRect($left, $top, $right, $bottom)';
}

enum _Border { white, black }

/// Content bounds of an RGBA image without uniform white or black (or transparent) borders; null when there is
/// nothing to crop. Each side is trimmed while whole lines are near-white or near-black, ignoring up to [noise] of
/// a line (scan specks). An axis is left uncropped when less than [minKeep] of it would remain
/// (mostly blank pages). [vertical] = false trims only the left and right sides (long strip: pages continue
/// each other vertically).
CropRect? detectCropBounds(
  Uint8List rgba,
  int width,
  int height, {
  bool vertical = true,
  int tolerance = 32,
  double noise = 0.01,
  double minKeep = 0.5,
}) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) return null;

  bool matches(int x, int y, _Border border) {
    final i = (y * width + x) * 4;
    if (rgba[i + 3] < 16) return true; // Transparent: matches either border.
    final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    return switch (border) {
      _Border.white => r >= 255 - tolerance && g >= 255 - tolerance && b >= 255 - tolerance,
      _Border.black => r <= tolerance && g <= tolerance && b <= tolerance,
    };
  }

  /// Whether a line is [border] apart from at most the noise limit.
  bool isBorderLine(int length, _Border border, (int, int) Function(int i) at) {
    final limit = max(1, (length * noise).floor());
    var misses = 0;
    for (var i = 0; i < length && misses <= limit; i++) {
      final (x, y) = at(i);
      if (!matches(x, y, border)) misses++;
    }
    return misses <= limit;
  }

  /// Steps from [from] towards [to] over border lines; bands of different colors may follow each other
  /// (a black scan edge, then a white margin).
  int trim(int from, int to, int step, int length, (int, int) Function(int line, int i) at) {
    var line = from;
    while (line != to) {
      final border = _Border.values.where((b) => isBorderLine(length, b, (i) => at(line, i))).firstOrNull;
      if (border == null) break;
      while (line != to && isBorderLine(length, border, (i) => at(line, i))) {
        line += step;
      }
    }
    return line;
  }

  // Each axis is trimmed within the other's bounds, so a band along one whole side (a scan edge) does not keep
  // the rows or columns crossing it from counting as border; repeated until stable.
  var left = 0, top = 0, right = width, bottom = height;
  for (var pass = 0; pass < 4; pass++) {
    final before = (left, top, right, bottom);
    if (vertical) {
      final (l, r) = (left, right);
      top = trim(top, bottom, 1, r - l, (line, i) => (l + i, line));
      if (top == bottom) return null; // Blank page.
      bottom = trim(bottom - 1, top - 1, -1, r - l, (line, i) => (l + i, line)) + 1;
    }
    final (t, b) = (top, bottom);
    left = trim(left, right, 1, b - t, (line, i) => (line, t + i));
    if (left == right) return null;
    right = trim(right - 1, left - 1, -1, b - t, (line, i) => (line, t + i)) + 1;
    if (before == (left, top, right, bottom)) break;
  }
  if (bottom - top < height * minKeep) {
    top = 0;
    bottom = height;
  }
  if (right - left < width * minKeep) {
    left = 0;
    right = width;
  }

  if (left == 0 && top == 0 && right == width && bottom == height) return null;
  return CropRect(left, top, right, bottom);
}
