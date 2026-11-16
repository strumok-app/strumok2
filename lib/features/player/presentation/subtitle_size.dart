import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_preferences.dart';

part 'subtitle_size.g.dart';

/// Subtitle font size in logical pixels (spec-09 key `video_player_subtitles_size`).
@Riverpod(keepAlive: true)
class SubtitleSize extends _$SubtitleSize {
  static const min = 16.0;
  static const max = 64.0;
  static const step = 4.0;
  static const defaultSize = 32.0;

  @override
  double build() =>
      ref.read(appPreferencesProvider).getDouble(AppPreferences.videoPlayerSubtitlesSize)?.clamp(min, max) ??
      defaultSize;

  Future<void> set(double value) async {
    state = value.clamp(min, max);
    await ref.read(appPreferencesProvider).setDouble(AppPreferences.videoPlayerSubtitlesSize, state);
  }
}
