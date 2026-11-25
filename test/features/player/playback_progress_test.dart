import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/player/data/playback_progress.dart';

void main() {
  group('PlaybackProgress', () {
    const duration = Duration(minutes: 31, seconds: 58);

    void play(PlaybackProgress progress, Duration from, Duration to) {
      for (var p = from; p <= to; p += const Duration(milliseconds: 500)) {
        progress.position(p);
      }
    }

    test('mpv jumping to the last frame of a stream that never played is not the end', () {
      final progress = PlaybackProgress()..reset(Duration.zero);
      progress.position(Duration.zero);
      progress.position(duration);
      expect(progress.reachedEnd(duration), isFalse);
    });

    test('playing up to the end is the end', () {
      final progress = PlaybackProgress()..reset(Duration.zero);
      play(progress, Duration.zero, duration - const Duration(seconds: 1));
      expect(progress.reachedEnd(duration), isTrue);
    });

    test('a stream that broke in the middle is not the end', () {
      final progress = PlaybackProgress()..reset(Duration.zero);
      play(progress, Duration.zero, const Duration(minutes: 10));
      expect(progress.reachedEnd(duration), isFalse);
    });

    test('resuming near the end counts the start position as reached', () {
      final start = duration - const Duration(seconds: 3);
      final progress = PlaybackProgress()..reset(start);
      progress.position(start - const Duration(seconds: 2));
      expect(progress.reachedEnd(duration), isTrue);
    });

    test('a requested seek to the end is the end', () {
      final progress = PlaybackProgress()..reset(Duration.zero);
      play(progress, Duration.zero, const Duration(minutes: 1));
      progress.seekTo(duration);
      progress.position(const Duration(minutes: 1, milliseconds: 500));
      progress.position(duration);
      expect(progress.reachedEnd(duration), isTrue);
    });

    test('a backward seek resets the reached position', () {
      final progress = PlaybackProgress()..reset(Duration.zero);
      play(progress, Duration.zero, duration - const Duration(seconds: 1));
      progress.seekTo(const Duration(minutes: 5));
      progress.position(const Duration(minutes: 5));
      progress.position(duration);
      expect(progress.reachedEnd(duration), isFalse);
    });
  });
}
