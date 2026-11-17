import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/manga/data/manga_page_images.dart';
import 'package:strumok/features/manga/domain/auto_crop.dart';

import '../../helpers/test_overrides.dart';

/// White [width]×[height] page with black content in [content].
Future<ui.Image> page(int width, int height, Rect content) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFFFFFFFF))
    ..drawRect(content, Paint()..color = const Color(0xFF402010));
  return recorder.endRecording().toImage(width, height);
}

void main() {
  final images = MangaPageImages(FakeCacheManager());

  test('remote pages use the network cache; anything else is a local file', () {
    expect(images.provider('https://img.example/1.jpg').runtimeType.toString(), 'CachedNetworkImageProvider');
    expect(
      (images.provider('/downloads/m/0/pages_UA/001.jpg') as FileImage).file.path,
      '/downloads/m/0/pages_UA/001.jpg',
    );
    expect((images.provider('file:///downloads/a%20b/1.jpg') as FileImage).file.path, '/downloads/a b/1.jpg');
  });

  testWidgets('crops a decoded page and caches the bounds per axis mode', (tester) async {
    final (full, strip) = (await tester.runAsync(() async {
      final image = await page(200, 300, const Rect.fromLTRB(20, 30, 180, 270));
      final full = await images.crop('p1', image, vertical: true);
      final strip = await images.crop('p1', image, vertical: false);
      image.dispose();
      return (full, strip);
    }))!;
    expect(full, const CropRect(20, 30, 180, 270));
    expect(strip, const CropRect(20, 0, 180, 300));
    expect(images.hasCrop('p1', vertical: true), isTrue);
    expect(images.cachedCrop('p1', vertical: false), strip);
  });

  testWidgets('large pages are analysed downscaled; bounds never cut content', (tester) async {
    final bounds = (await tester.runAsync(() async {
      final image = await page(1200, 1800, const Rect.fromLTRB(100, 150, 1100, 1650));
      final bounds = await images.crop('p2', image, vertical: true);
      image.dispose();
      return bounds;
    }))!;
    expect(bounds.left, inInclusiveRange(88, 100));
    expect(bounds.top, inInclusiveRange(138, 150));
    expect(bounds.right, inInclusiveRange(1100, 1112));
    expect(bounds.bottom, inInclusiveRange(1650, 1662));
  });

  test('remembers aspect ratios, dropping the oldest', () {
    final images = MangaPageImages(FakeCacheManager());
    for (var i = 0; i < 501; i++) {
      images.rememberAspectRatio('p$i', 0.5);
    }
    expect(images.aspectRatio('p0'), isNull);
    expect(images.aspectRatio('p500'), 0.5);
  });
}
