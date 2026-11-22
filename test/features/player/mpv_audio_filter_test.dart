import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/player/data/mpv_audio_filter.dart';
import 'package:strumok/features/player/domain/equalizer.dart';

void main() {
  group('mpvAudioFilter', () {
    test('neutral effects need no filter', () {
      expect(const AudioEffects().isNeutral, isTrue);
      expect(mpvAudioFilter(const AudioEffects()), '');
    });

    test('one peaking filter per non-zero band', () {
      expect(
        mpvAudioFilter(const AudioEffects(bands: [4, 0, 0, 0, -2.5])),
        'lavfi=[equalizer=f=60:width_type=o:width=2:g=4.0,equalizer=f=14000:width_type=o:width=2:g=-2.5]',
      );
    });

    test('normalization alone', () {
      expect(mpvAudioFilter(const AudioEffects(volumeNormalization: true)), 'lavfi=[dynaudnorm=f=150:g=15]');
    });

    test('bands, then compression, then normalization in one chain', () {
      expect(
        mpvAudioFilter(const AudioEffects(bands: [4, 0, 0, 0, 0], volumeNormalization: true, dynamicCompression: true)),
        'lavfi=[equalizer=f=60:width_type=o:width=2:g=4.0,'
        'acompressor=threshold=-18dB:ratio=3:attack=20:release=250:makeup=2,dynaudnorm=f=150:g=15]',
      );
    });
  });
}
