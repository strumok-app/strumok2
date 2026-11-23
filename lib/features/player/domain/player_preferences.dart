import 'dart:math';

import 'package:flutter/foundation.dart';

import 'equalizer.dart';
import 'player_session.dart';

/// Spec-09 key `video_player_setting_ends_action` (values by `.name`).
enum EndAction { playNext, playAgain, doNothing }

/// Persisted player settings (spec-06 §6.5, spec-09 §5).
@immutable
final class PlayerPreferences {
  final StartFrom startFrom;

  /// Start position for [StartFrom.fromFixedPosition], seconds.
  final int fixedPosition;
  final EndAction endAction;
  final bool shuffle;
  final List<double> equalizer;

  /// Evens out loudness over time (mpv `dynaudnorm`).
  final bool volumeNormalization;

  /// Reduces the gap between loud and quiet sounds (mpv `acompressor`).
  final bool dynamicCompression;

  /// Keep playing in a mini player after leaving the player (spec-06 §6.9).
  final bool floatingPlayer;

  /// Upscaler id (spec-13); null is off. May name a preset that no longer exists or isn't supported here.
  final String? upscaler;

  const PlayerPreferences({
    this.startFrom = StartFrom.fromRemembered,
    this.fixedPosition = 0,
    this.endAction = EndAction.playNext,
    this.shuffle = false,
    this.equalizer = const [0, 0, 0, 0, 0],
    this.volumeNormalization = false,
    this.dynamicCompression = false,
    this.floatingPlayer = true,
    this.upscaler,
  });

  PlayerPreferences copyWith({
    StartFrom? startFrom,
    int? fixedPosition,
    EndAction? endAction,
    bool? shuffle,
    List<double>? equalizer,
    bool? volumeNormalization,
    bool? dynamicCompression,
    bool? floatingPlayer,
    String? upscaler,
    bool clearUpscaler = false,
  }) => PlayerPreferences(
    startFrom: startFrom ?? this.startFrom,
    fixedPosition: fixedPosition ?? this.fixedPosition,
    endAction: endAction ?? this.endAction,
    shuffle: shuffle ?? this.shuffle,
    equalizer: equalizer ?? this.equalizer,
    volumeNormalization: volumeNormalization ?? this.volumeNormalization,
    dynamicCompression: dynamicCompression ?? this.dynamicCompression,
    floatingPlayer: floatingPlayer ?? this.floatingPlayer,
    upscaler: clearUpscaler ? null : upscaler ?? this.upscaler,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerPreferences &&
      other.startFrom == startFrom &&
      other.fixedPosition == fixedPosition &&
      other.endAction == endAction &&
      other.shuffle == shuffle &&
      listEquals(other.equalizer, equalizer) &&
      other.volumeNormalization == volumeNormalization &&
      other.dynamicCompression == dynamicCompression &&
      other.floatingPlayer == floatingPlayer &&
      other.upscaler == upscaler;

  @override
  int get hashCode => Object.hash(
    startFrom,
    fixedPosition,
    endAction,
    shuffle,
    Object.hashAll(equalizer),
    volumeNormalization,
    dynamicCompression,
    floatingPlayer,
    upscaler,
  );

  AudioEffects get audioEffects =>
      AudioEffects(bands: equalizer, volumeNormalization: volumeNormalization, dynamicCompression: dynamicCompression);

  EqualizerPreset? get equalizerPreset => EqualizerPreset.of(equalizer);
}

/// The item "next" plays: a random other item when shuffling, otherwise the following one; null at the end.
int? nextItemIndex(int current, int count, {bool shuffle = false, Random? random}) {
  if (shuffle && count > 1) {
    final pick = (random ?? Random()).nextInt(count - 1);
    return pick >= current ? pick + 1 : pick;
  }
  return current + 1 < count ? current + 1 : null;
}

/// Playback speeds offered by the player (spec-06 §6.5: 0.5–2.0).
const playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
