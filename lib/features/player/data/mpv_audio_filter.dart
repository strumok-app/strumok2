import '../domain/equalizer.dart';

const _volumeNormalizationFilter = 'dynaudnorm=f=150:g=15';
const _dynamicCompressionFilter = 'acompressor=threshold=-18dB:ratio=3:attack=20:release=250:makeup=2';

/// mpv `af` value for [effects] (spec-06 §6.5): one peaking filter (two octaves wide) per non-zero band, then
/// dynamic compression, then volume normalization (so the normalizer sees the final dynamics). Empty when neutral.
String mpvAudioFilter(AudioEffects effects) {
  final filters = [
    for (final (i, gain) in effects.bands.indexed)
      if (gain != 0 && i < equalizerFrequencies.length)
        'equalizer=f=${equalizerFrequencies[i]}:width_type=o:width=2:g=${gain.toStringAsFixed(1)}',
    if (effects.dynamicCompression) _dynamicCompressionFilter,
    if (effects.volumeNormalization) _volumeNormalizationFilter,
  ];
  return filters.isEmpty ? '' : 'lavfi=[${filters.join(',')}]';
}
