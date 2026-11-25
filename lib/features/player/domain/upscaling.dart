import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Desktop upscaling with mpv user shaders (spec-13).
///
/// U0 field testing showed the FSRCNNX, RAVU and NNEDI3 families made no noticeable difference, so they were dropped;
/// Anime4K (Mode A fast + HQ A/B/C) and a custom detail/sharpen/grain chain remain.
enum UpscalerFamily { anime4k, custom }

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
///
/// Anime4K Mode A (fast) and the HQ modes (A/B/C) ship; a custom experimental chain is offered for testing. The
/// FSRCNNX, RAVU and NNEDI3 families were removed outright after U0 testing found they made no noticeable difference.
const upscalers = <Upscaler>[
  Upscaler('anime4k_a_fast', UpscalerFamily.anime4k, UpscalerCost.light, forAnime: true),
  Upscaler('anime4k_a_hq', UpscalerFamily.anime4k, UpscalerCost.heavy, forAnime: true),
  Upscaler('anime4k_b_hq', UpscalerFamily.anime4k, UpscalerCost.heavy, forAnime: true),
  Upscaler('anime4k_c_hq', UpscalerFamily.anime4k, UpscalerCost.medium, forAnime: true),
  // Experimental test chain (spec-13): SSimSuperRes luma detail recovery + AMD CAS sharpening + film grain.
  Upscaler('custom_detail_cas_grain', UpscalerFamily.custom, UpscalerCost.medium),
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
