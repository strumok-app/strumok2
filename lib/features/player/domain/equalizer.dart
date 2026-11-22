import 'package:flutter/foundation.dart';

/// Band centers (Hz) of the 5-band equalizer (spec-06 §6.5).
const equalizerFrequencies = [60, 230, 910, 4000, 14000];

/// Gain range per band, dB.
const equalizerMaxGain = 12.0;

enum EqualizerPreset {
  reset([0, 0, 0, 0, 0]),
  clearDialogue([0, 2, 4, 5, 1]),
  cinema([4, 2, 0, 2, 4]),
  night([-3, 0, 3, 4, -2]),
  action([5, 3, -1, 1, 3]),
  max([equalizerMaxGain, equalizerMaxGain, equalizerMaxGain, equalizerMaxGain, equalizerMaxGain]);

  final List<double> bands;

  const EqualizerPreset(this.bands);

  /// The preset with exactly these gains; null for a custom setting.
  static EqualizerPreset? of(List<double> bands) {
    for (final preset in values) {
      if (_same(preset.bands, bands)) return preset;
    }
    return null;
  }
}

bool _same(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Everything the audio chain applies on top of the decoded sound; backends turn it into their own filters.
@immutable
final class AudioEffects {
  /// Gains (dB) per [equalizerFrequencies] band.
  final List<double> bands;

  /// Evens out loudness over time: quiet passages are lifted, loud ones tamed.
  final bool volumeNormalization;

  /// Tames sudden loud sounds so dialogue stays audible at a low volume.
  final bool dynamicCompression;

  const AudioEffects({
    this.bands = const [0, 0, 0, 0, 0],
    this.volumeNormalization = false,
    this.dynamicCompression = false,
  });

  /// Nothing to apply.
  bool get isNeutral => !volumeNormalization && !dynamicCompression && bands.every((gain) => gain == 0);

  @override
  bool operator ==(Object other) =>
      other is AudioEffects &&
      listEquals(other.bands, bands) &&
      other.volumeNormalization == volumeNormalization &&
      other.dynamicCompression == dynamicCompression;

  @override
  int get hashCode => Object.hash(Object.hashAll(bands), volumeNormalization, dynamicCompression);

  @override
  String toString() =>
      'AudioEffects(bands: $bands, volumeNormalization: $volumeNormalization, dynamicCompression: $dynamicCompression)';
}

/// Spec-09 `video_player_equalizer_bands`: csv of 5 doubles; anything malformed reads as flat.
List<double> parseEqualizerBands(String? csv) {
  final parts = csv?.split(',') ?? const [];
  if (parts.length != equalizerFrequencies.length) return EqualizerPreset.reset.bands;
  final bands = parts.map((p) => double.tryParse(p.trim())).toList();
  if (bands.contains(null)) return EqualizerPreset.reset.bands;
  return [for (final b in bands) b!.clamp(-equalizerMaxGain, equalizerMaxGain).toDouble()];
}

String formatEqualizerBands(List<double> bands) => bands.map((b) => b.toString()).join(',');
