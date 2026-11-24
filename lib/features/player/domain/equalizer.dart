import 'package:flutter/foundation.dart';

/// Band centers (Hz) of the 10-band equalizer: VLC's default band set (spec-06 §6.5).
const equalizerFrequencies = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];

/// Gain range per band and for the preamp, dB (as in VLC).
const equalizerMaxGain = 20.0;

const _flatBands = <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

/// Equalizer setting: a preamp applied before the bands, then one gain per [equalizerFrequencies] band, all in dB.
@immutable
final class EqualizerGains {
  final double preamp;
  final List<double> bands;

  const EqualizerGains({this.preamp = 0, this.bands = _flatBands});

  static const flat = EqualizerGains();

  bool get isFlat => preamp == 0 && bands.every((gain) => gain == 0);

  EqualizerGains withPreamp(double gain) => EqualizerGains(preamp: _clamp(gain), bands: bands);

  EqualizerGains withBand(int band, double gain) =>
      EqualizerGains(preamp: preamp, bands: [...bands]..[band] = _clamp(gain));

  /// Within ±[equalizerMaxGain]; a band list of the wrong length reads as flat.
  EqualizerGains clamped() => EqualizerGains(
    preamp: _clamp(preamp),
    bands: bands.length == equalizerFrequencies.length ? [for (final b in bands) _clamp(b)] : _flatBands,
  );

  @override
  bool operator ==(Object other) => other is EqualizerGains && other.preamp == preamp && listEquals(other.bands, bands);

  @override
  int get hashCode => Object.hash(preamp, Object.hashAll(bands));

  @override
  String toString() => 'EqualizerGains(preamp: $preamp, bands: $bands)';
}

double _clamp(double gain) => gain.clamp(-equalizerMaxGain, equalizerMaxGain).toDouble();

/// Presets for films and series (spec-06 §6.5).
enum EqualizerPreset {
  reset(EqualizerGains()),
  clearDialogue(EqualizerGains(bands: [-2, -1, 1, 3, 4, 5, 3, 1, 0, 0])),
  cinema(EqualizerGains(bands: [4, 3, 1, 0, 0, 1, 2, 3, 4, 4])),
  night(EqualizerGains(bands: [-4, -2, 0, 2, 3, 4, 3, 0, -2, -3])),
  action(EqualizerGains(bands: [6, 5, 3, 0, -1, 1, 2, 3, 3, 3]));

  final EqualizerGains gains;

  const EqualizerPreset(this.gains);

  /// The preset with exactly these gains; null for a custom setting.
  static EqualizerPreset? of(EqualizerGains gains) {
    for (final preset in values) {
      if (preset.gains == gains) return preset;
    }
    return null;
  }
}

/// Everything the audio chain applies on top of the decoded sound; backends turn it into their own filters.
@immutable
final class AudioEffects {
  final EqualizerGains equalizer;

  /// Evens out loudness over time: quiet passages are lifted, loud ones tamed.
  final bool volumeNormalization;

  /// Tames sudden loud sounds so dialogue stays audible at a low volume.
  final bool dynamicCompression;

  const AudioEffects({
    this.equalizer = EqualizerGains.flat,
    this.volumeNormalization = false,
    this.dynamicCompression = false,
  });

  /// Nothing to apply.
  bool get isNeutral => !volumeNormalization && !dynamicCompression && equalizer.isFlat;

  @override
  bool operator ==(Object other) =>
      other is AudioEffects &&
      other.equalizer == equalizer &&
      other.volumeNormalization == volumeNormalization &&
      other.dynamicCompression == dynamicCompression;

  @override
  int get hashCode => Object.hash(equalizer, volumeNormalization, dynamicCompression);

  @override
  String toString() =>
      'AudioEffects(equalizer: $equalizer, volumeNormalization: $volumeNormalization, '
      'dynamicCompression: $dynamicCompression)';
}

/// Spec-09 `video_player_equalizer_bands` (csv of 10 doubles) and `video_player_equalizer_preamp`. Anything
/// malformed — including band lists saved by the earlier 5-band equalizer — reads as flat.
EqualizerGains parseEqualizerGains({String? bandsCsv, double? preamp}) {
  final parts = bandsCsv?.split(',') ?? const [];
  final bands = parts.map((p) => double.tryParse(p.trim())).toList();
  final valid = bands.length == equalizerFrequencies.length && !bands.contains(null);
  return EqualizerGains(preamp: preamp ?? 0, bands: valid ? [for (final b in bands) b!] : _flatBands).clamped();
}

String formatEqualizerBands(List<double> bands) => bands.map((b) => b.toString()).join(',');
