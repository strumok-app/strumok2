import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/manga/domain/auto_crop.dart';

typedef Rgba = (int, int, int, int);

const white = (255, 255, 255, 255);
const offWhite = (240, 242, 238, 255);
const black = (0, 0, 0, 255);
const ink = (90, 60, 40, 255);
const transparent = (0, 0, 0, 0);

/// [width]×[height] image of [background] with [content] filling `[left, right) × [top, bottom)`.
Uint8List image(
  int width,
  int height, {
  Rgba background = white,
  Rgba content = ink,
  (int, int, int, int)? box,
  List<(int, int)> specks = const [],
}) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inside = box != null && x >= box.$1 && y >= box.$2 && x < box.$3 && y < box.$4;
      final speck = specks.contains((x, y));
      final (r, g, b, a) = inside || speck ? content : background;
      final i = (y * width + x) * 4;
      bytes
        ..[i] = r
        ..[i + 1] = g
        ..[i + 2] = b
        ..[i + 3] = a;
    }
  }
  return bytes;
}

void main() {
  test('trims white borders on all sides', () {
    final rgba = image(100, 120, box: (10, 20, 90, 100));
    expect(detectCropBounds(rgba, 100, 120), const CropRect(10, 20, 90, 100));
  });

  test('trims black and near-white borders', () {
    expect(
      detectCropBounds(image(100, 100, background: black, box: (5, 6, 95, 94)), 100, 100),
      const CropRect(5, 6, 95, 94),
    );
    expect(
      detectCropBounds(image(100, 100, background: offWhite, box: (8, 8, 92, 92)), 100, 100),
      const CropRect(8, 8, 92, 92),
    );
  });

  test('each side keeps its own border color', () {
    // White page with a black band on the left edge only.
    final rgba = image(100, 100, box: (20, 10, 90, 90));
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 5; x++) {
        rgba.setAll((y * 100 + x) * 4, [0, 0, 0, 255]);
      }
    }
    expect(detectCropBounds(rgba, 100, 100), const CropRect(20, 10, 90, 90));
  });

  test('transparent pixels count as border', () {
    expect(
      detectCropBounds(image(50, 50, background: transparent, box: (10, 10, 40, 40)), 50, 50),
      const CropRect(10, 10, 40, 40),
    );
  });

  test('ignores scan specks within the noise limit', () {
    final rgba = image(200, 200, box: (20, 20, 180, 180), specks: [(100, 3), (101, 3)]);
    expect(detectCropBounds(rgba, 200, 200), const CropRect(20, 20, 180, 180));
  });

  test('nothing to crop when content touches the edges', () {
    expect(detectCropBounds(image(40, 40, box: (0, 0, 40, 40)), 40, 40), isNull);
  });

  test('blank pages are not cropped', () {
    expect(detectCropBounds(image(40, 40), 40, 40), isNull);
  });

  test('an axis that would lose more than half is left as is', () {
    // Small drawing in a mostly blank page: only the horizontal bounds are wide enough.
    final rgba = image(100, 100, box: (10, 45, 90, 55));
    expect(detectCropBounds(rgba, 100, 100), const CropRect(10, 0, 90, 100));
  });

  test('vertical: false trims only the sides (long strip)', () {
    final rgba = image(100, 100, box: (10, 20, 90, 80));
    expect(detectCropBounds(rgba, 100, 100, vertical: false), const CropRect(10, 0, 90, 100));
  });

  test('rejects buffers that do not match the size', () {
    expect(detectCropBounds(Uint8List(10), 10, 10), isNull);
  });

  test('scales sampled bounds back with a one-sample margin', () {
    const bounds = CropRect(10, 20, 90, 100);
    expect(
      bounds.scale(fromWidth: 100, fromHeight: 120, toWidth: 1000, toHeight: 1200),
      const CropRect(90, 190, 910, 1010),
    );
    expect(
      const CropRect(0, 0, 100, 120).scale(fromWidth: 100, fromHeight: 120, toWidth: 1000, toHeight: 1200),
      const CropRect(0, 0, 1000, 1200),
    );
  });
}
