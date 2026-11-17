import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/image_cache.dart';
import '../domain/auto_crop.dart';

part 'manga_page_images.g.dart';

@Riverpod(keepAlive: true)
MangaPageImages mangaPageImages(Ref ref) => MangaPageImages(ref.watch(mangaPageCacheManagerProvider));

/// Page image providers, plus per-page crop bounds and aspect ratios remembered across rebuilds (so a page
/// scrolled back into a long strip is laid out at its final size right away).
class MangaPageImages {
  static const _maxRemembered = 500;

  // Crop detection runs on a downscaled copy; small enough to scan on the UI isolate in a few milliseconds.
  static const _sampleWidth = 300;
  static const _sampleHeight = 4096;

  final BaseCacheManager _cache;
  // Insertion-ordered: the oldest entries are dropped first.
  final _crops = <String, CropRect?>{};
  final _aspects = <String, double>{};

  MangaPageImages(this._cache);

  /// Remote pages go through the shared client and the manga page disk cache with the source headers (spec-02 §2.3);
  /// anything else is a local file (downloaded pages, spec-08).
  ImageProvider provider(String page, {Map<String, String>? headers}) {
    final uri = Uri.tryParse(page);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return CachedNetworkImageProvider(page, headers: headers, cacheManager: _cache);
    }
    return FileImage(File(uri != null && uri.scheme == 'file' ? uri.toFilePath() : page));
  }

  /// Width / height of the shown (cropped) page, when it has been loaded before.
  double? aspectRatio(String page) => _aspects[page];

  bool hasCrop(String page, {required bool vertical}) => _crops.containsKey(_cropKey(page, vertical));

  /// Cached result of [crop]; null also when nothing is cropped.
  CropRect? cachedCrop(String page, {required bool vertical}) => _crops[_cropKey(page, vertical)];

  /// Content bounds of [image] without uniform borders; null when there is nothing to crop.
  Future<CropRect?> crop(String page, ui.Image image, {required bool vertical}) async {
    final key = _cropKey(page, vertical);
    if (_crops.containsKey(key)) return _crops[key];
    final bounds = await _detect(image, vertical);
    _remember(_crops, key, bounds);
    return bounds;
  }

  void rememberAspectRatio(String page, double aspectRatio) => _remember(_aspects, page, aspectRatio);

  Future<CropRect?> _detect(ui.Image image, bool vertical) async {
    final scale = min(1.0, min(_sampleWidth / image.width, _sampleHeight / image.height));
    final width = max(1, (image.width * scale).round()), height = max(1, (image.height * scale).round());
    var sample = image;
    if (scale < 1) {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..filterQuality = FilterQuality.low,
      );
      final picture = recorder.endRecording();
      sample = await picture.toImage(width, height);
      picture.dispose();
    }
    try {
      final data = await sample.toByteData();
      if (data == null) return null;
      final bounds = detectCropBounds(data.buffer.asUint8List(), width, height, vertical: vertical);
      if (bounds == null || identical(sample, image)) return bounds;
      return bounds.scale(fromWidth: width, fromHeight: height, toWidth: image.width, toHeight: image.height);
    } finally {
      if (!identical(sample, image)) sample.dispose();
    }
  }

  static String _cropKey(String page, bool vertical) => '${vertical ? 'v' : 'h'}|$page';

  static void _remember<T>(Map<String, T> map, String key, T value) {
    map.remove(key);
    map[key] = value;
    if (map.length > _maxRemembered) map.remove(map.keys.first);
  }
}
