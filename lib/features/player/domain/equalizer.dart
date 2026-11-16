/// Band centers (Hz) of the 5-band equalizer (spec-06 §6.5).
const equalizerFrequencies = [60, 230, 910, 4000, 14000];

/// Gain range per band, dB.
const equalizerMaxGain = 12.0;

enum EqualizerPreset {
  reset([0, 0, 0, 0, 0]),
  clearDialogue([0, 2, 4, 5, 1]),
  cinema([4, 2, 0, 2, 4]),
  night([-3, 0, 3, 4, -2]),
  action([5, 3, -1, 1, 3]);

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

/// mpv `af` value: one peaking filter (two octaves wide) per non-zero band; empty when flat.
String equalizerFilter(List<double> bands) {
  final filters = [
    for (final (i, gain) in bands.indexed)
      if (gain != 0 && i < equalizerFrequencies.length)
        'equalizer=f=${equalizerFrequencies[i]}:width_type=o:width=2:g=${gain.toStringAsFixed(1)}',
  ];
  return filters.isEmpty ? '' : 'lavfi=[${filters.join(',')}]';
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
