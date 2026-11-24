import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Desktop upscaling with mpv user shaders (spec-13).
enum UpscalerFamily { fsrcnnx, ravu, nnedi3, anime4k }

/// GPU cost on the reference iGPU (spec-13 §13.3): heavy presets exceed one 24 fps frame there.
enum UpscalerCost { light, medium, heavy }

@immutable
final class Upscaler {
  /// Persisted (`video_player_upscaler`), never renamed.
  final String id;
  final UpscalerFamily family;
  final UpscalerCost cost;

  /// UI hint: tuned for anime.
  final bool forAnime;

  const Upscaler(this.id, this.family, this.cost, {this.forAnime = false});

  @override
  String toString() => 'Upscaler($id)';
}

/// The catalog (spec-13 §13.3), in display order within each family.
const upscalers = <Upscaler>[
  Upscaler('fsrcnnx_8', UpscalerFamily.fsrcnnx, UpscalerCost.light),
  Upscaler('fsrcnnx_16', UpscalerFamily.fsrcnnx, UpscalerCost.heavy),
  Upscaler('ravu_lite_r4', UpscalerFamily.ravu, UpscalerCost.light),
  Upscaler('ravu_zoom_r3', UpscalerFamily.ravu, UpscalerCost.light),
  Upscaler('nnedi3_64', UpscalerFamily.nnedi3, UpscalerCost.medium),
  Upscaler('nnedi3_128', UpscalerFamily.nnedi3, UpscalerCost.heavy),
  Upscaler('anime4k_a_fast', UpscalerFamily.anime4k, UpscalerCost.light, forAnime: true),
  Upscaler('anime4k_a_hq', UpscalerFamily.anime4k, UpscalerCost.heavy, forAnime: true),
  Upscaler('anime4k_b_hq', UpscalerFamily.anime4k, UpscalerCost.heavy, forAnime: true),
  Upscaler('anime4k_c_hq', UpscalerFamily.anime4k, UpscalerCost.medium, forAnime: true),
];

/// Unknown, removed or null ids mean "off".
Upscaler? upscalerById(String? id) {
  for (final upscaler in upscalers) {
    if (upscaler.id == id) return upscaler;
  }
  return null;
}

/// Physical output size for mpv: the video fitted (contain) into [viewPx], long side capped at [maxLongSide].
/// Null (render at the video's own size) when that is not larger than the video, e.g. in the floating player.
({int width, int height})? upscaleOutputSize(Size viewPx, Size videoPx, {int maxLongSide = 3840}) {
  if (videoPx.width <= 0 || videoPx.height <= 0 || viewPx.width <= 0 || viewPx.height <= 0) return null;
  final scale = [
    viewPx.width / videoPx.width,
    viewPx.height / videoPx.height,
    maxLongSide / max(videoPx.width, videoPx.height),
  ].reduce(min);
  if (scale <= 1) return null;
  return (width: (videoPx.width * scale).round(), height: (videoPx.height * scale).round());
}
