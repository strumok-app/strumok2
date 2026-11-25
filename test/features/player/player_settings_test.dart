import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/player/domain/equalizer.dart';
import 'package:strumok/features/player/domain/player_preferences.dart';
import 'package:strumok/features/player/domain/player_session.dart';
import 'package:strumok/features/player/domain/upscaling.dart';
import 'package:strumok/features/player/presentation/player_controller.dart';
import 'package:strumok/features/player/presentation/player_settings.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_player.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('equalizer', () {
    test('presets are recognized by preamp and bands; anything else is custom', () {
      for (final preset in EqualizerPreset.values) {
        expect(preset.gains.bands, hasLength(10), reason: preset.name);
        expect(EqualizerPreset.of(preset.gains), preset);
      }
      const cinema = EqualizerGains(bands: [4, 3, 1, 0, 0, 1, 2, 3, 4, 4]);
      expect(EqualizerPreset.of(cinema), EqualizerPreset.cinema);
      expect(EqualizerPreset.of(cinema.withBand(9, 5)), isNull);
      expect(EqualizerPreset.of(cinema.withPreamp(-1)), isNull, reason: 'the preamp is part of a preset');
    });

    test('10-band csv round trip; anything else, including 5-band lists, reads as flat; gains clamp to ±20 dB', () {
      const gains = EqualizerGains(preamp: -3, bands: [5, 3, -1, 1, 3, 0, 0, 2, 2, 1]);
      expect(parseEqualizerGains(bandsCsv: formatEqualizerBands(gains.bands), preamp: -3), gains);
      expect(parseEqualizerGains(), EqualizerGains.flat);
      expect(parseEqualizerGains(bandsCsv: '4,2,0,2,4'), EqualizerGains.flat, reason: 'legacy 5-band value');
      expect(parseEqualizerGains(bandsCsv: '1,x,3,4,5,6,7,8,9,10'), EqualizerGains.flat);
      expect(
        parseEqualizerGains(bandsCsv: '30,-30,0,0,0,0,0,0,0,0', preamp: 25),
        const EqualizerGains(preamp: 20, bands: [20, -20, 0, 0, 0, 0, 0, 0, 0, 0]),
      );
    });
  });

  group('nextItemIndex', () {
    test('in order: the following item, none after the last', () {
      expect(nextItemIndex(0, 3), 1);
      expect(nextItemIndex(2, 3), isNull);
    });

    test('shuffle: any other item, never the current one', () {
      final random = Random(1);
      final picks = {for (var i = 0; i < 100; i++) nextItemIndex(2, 5, shuffle: true, random: random)};
      expect(picks, {0, 1, 3, 4});
      expect(nextItemIndex(0, 1, shuffle: true), isNull, reason: 'a single item has no next');
    });
  });

  group('settings and the controller', () {
    late FakeVideoBackend backend;
    late ProviderContainer c;
    late PlayerController controller;

    FakeMediaItem episode(int n) =>
        FakeMediaItem(n, 'Episode ${n + 1}', sourceList: [FakeVideoSource('A', url: 'https://a.example/$n.m3u8')]);

    Future<void> setUpWith({
      Map<String, Object> prefs = const {},
      int items = 3,
      List<Upscaler> supportedUpscalers = const [],
    }) async {
      final details = FakeDetails(
        'alpha',
        'm1',
        title: 'Movie',
        loadItems: () async => [for (var i = 0; i < items; i++) episode(i)],
      );
      c = ProviderContainer(
        overrides: await testOverrides(
          bundle: SupplierBundleReady(
            FakeBundle([
              FakeSupplier('alpha', details: {'m1': details}),
            ]),
            bundleInfo('4.0.0'),
          ),
          prefs: await createTestPreferences(prefs),
          videoBackend: () => backend = FakeVideoBackend(supportedUpscalers: supportedUpscalers),
        ),
      );
      addTearDown(c.dispose);
      addTearDown(pumpEventQueue);
      controller = c.read(playerControllerProvider.notifier);
      await c.read(collectionItemsProvider.future);
      await c
          .read(collectionItemsProvider.notifier)
          .save(
            const CollectionItem(
              id: 'm1',
              supplier: 'alpha',
              title: 'Movie',
              image: '',
              positions: {0: MediaItemPosition(position: 300, length: 3000)},
              status: CollectionStatus.inProgress,
            ),
          );
    }

    test('settings persist under the spec-09 keys', () async {
      await setUpWith();
      final settings = c.read(playerSettingsProvider.notifier);
      await settings.setStartFrom(StartFrom.fromFixedPosition);
      await settings.setFixedPosition(90);
      await settings.setEndAction(EndAction.playAgain);
      await settings.setShuffle(true);
      await settings.setEqualizer(const EqualizerGains(preamp: -2, bands: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
      await settings.setVolumeNormalization(true);
      await settings.setDynamicCompression(true);
      expect(c.read(playerSettingsProvider).floatingPlayer, isTrue, reason: 'floating player is on by default');
      await settings.setFloatingPlayer(false);

      final prefs = c.read(appPreferencesProvider);
      expect(prefs.getString(AppPreferences.videoPlayerStartFrom), 'fromFixedPosition');
      expect(prefs.getInt(AppPreferences.videoPlayerFixedPosition), 90);
      expect(prefs.getString(AppPreferences.videoPlayerEndsAction), 'playAgain');
      expect(prefs.getBool(AppPreferences.videoPlayerShuffleMode), isTrue);
      expect(prefs.getString(AppPreferences.videoPlayerEqualizerBands), '1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0');
      expect(prefs.getDouble(AppPreferences.videoPlayerEqualizerPreamp), -2);
      expect(prefs.getBool(AppPreferences.videoPlayerVolumeNormalization), isTrue);
      expect(prefs.getBool(AppPreferences.videoPlayerDynamicCompression), isTrue);
      expect(prefs.getBool(AppPreferences.floatingVideoPlayerEnabled), isFalse);

      c.invalidate(playerSettingsProvider);
      expect(
        c.read(playerSettingsProvider),
        const PlayerPreferences(
          startFrom: StartFrom.fromFixedPosition,
          fixedPosition: 90,
          endAction: EndAction.playAgain,
          shuffle: true,
          equalizer: EqualizerGains(preamp: -2, bands: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
          volumeNormalization: true,
          dynamicCompression: true,
          floatingPlayer: false,
        ),
      );
    });

    test('start from the beginning or a fixed position instead of the remembered one', () async {
      await setUpWith(prefs: {AppPreferences.videoPlayerStartFrom: 'fromBeginning'});
      await controller.open('alpha', 'm1', item: 0);
      expect(backend.opened.last.start, Duration.zero);

      await c.read(playerSettingsProvider.notifier).setStartFrom(StartFrom.fromFixedPosition);
      await c.read(playerSettingsProvider.notifier).setFixedPosition(90);
      await controller.selectItem(1);
      expect(backend.opened.last.start, const Duration(seconds: 90));
    });

    test('on end: play again reopens the same item from 0; do nothing stays', () async {
      await setUpWith(prefs: {AppPreferences.videoPlayerEndsAction: 'playAgain'});
      await controller.open('alpha', 'm1', item: 1);
      backend.end();
      await pumpEventQueue();
      expect(c.read(playerControllerProvider)!.itemIndex, 1);
      expect(backend.opened.last.link.toString(), 'https://a.example/1.m3u8');
      expect(backend.opened.last.start, Duration.zero);

      await c.read(playerSettingsProvider.notifier).setEndAction(EndAction.doNothing);
      final opened = backend.opened.length;
      backend.end();
      await pumpEventQueue();
      expect(backend.opened, hasLength(opened));
    });

    test('on end with shuffle: another item at random; without: the following one', () async {
      await setUpWith(prefs: {AppPreferences.videoPlayerShuffleMode: true}, items: 2);
      await controller.open('alpha', 'm1', item: 1);
      backend.end();
      await pumpEventQueue();
      expect(c.read(playerControllerProvider)!.itemIndex, 0, reason: 'the only other item');
    });

    test('speed and equalizer reach the backend and survive item changes', () async {
      await setUpWith(prefs: {AppPreferences.videoPlayerEqualizerBands: '4,3,1,0,0,1,2,3,4,4'});
      await controller.open('alpha', 'm1', item: 0);
      expect(backend.audioEffects, AudioEffects(equalizer: EqualizerPreset.cinema.gains));

      await controller.setSpeed(1.5);
      await controller.setEqualizer(EqualizerPreset.reset.gains);
      expect(backend.calls.sublist(backend.calls.length - 2), ['speed:1.5', 'effects']);
      expect(backend.audioEffects.isNeutral, isTrue);

      await controller.next();
      expect(c.read(playerControllerProvider)!.speed, 1.5);
      expect(c.read(playerSettingsProvider).equalizer, EqualizerGains.flat);

      await controller.setVolumeNormalization(true);
      expect(backend.audioEffects, const AudioEffects(volumeNormalization: true));
      await controller.next();
      expect(backend.audioEffects, const AudioEffects(volumeNormalization: true));
    });

    group('upscaler (spec-13)', () {
      final anime4k = upscalerById('anime4k_a_fast')!;

      test('persists the id under video_player_upscaler; off removes it; unknown ids resolve to off', () async {
        await setUpWith(prefs: {AppPreferences.videoPlayerUpscaler: 'artcnn_c4f16'});
        expect(c.read(playerSettingsProvider).upscaler, 'artcnn_c4f16');
        expect(upscalerById(c.read(playerSettingsProvider).upscaler), isNull, reason: 'dropped preset reads as off');

        final settings = c.read(playerSettingsProvider.notifier);
        await settings.setUpscaler('anime4k_a_fast');
        expect(c.read(appPreferencesProvider).getString(AppPreferences.videoPlayerUpscaler), 'anime4k_a_fast');
        c.invalidate(playerSettingsProvider);
        expect(c.read(playerSettingsProvider).upscaler, 'anime4k_a_fast');

        await settings.setUpscaler(null);
        expect(c.read(appPreferencesProvider).getString(AppPreferences.videoPlayerUpscaler), isNull);
        expect(c.read(playerSettingsProvider).upscaler, isNull);
      });

      test('the saved upscaler is applied when playback starts, only where it is supported', () async {
        await setUpWith(prefs: {AppPreferences.videoPlayerUpscaler: 'anime4k_a_fast'}, supportedUpscalers: [anime4k]);
        await controller.open('alpha', 'm1');
        expect(backend.upscaler, anime4k);
        expect(controller.upscaler, anime4k);
        expect(controller.supportedUpscalers, [anime4k]);
      });

      test('unsupported here (Android, Windows for now): nothing applied, nothing offered', () async {
        await setUpWith(prefs: {AppPreferences.videoPlayerUpscaler: 'anime4k_a_fast'});
        await controller.open('alpha', 'm1');
        expect(backend.calls.where((call) => call.startsWith('upscaler')), isEmpty);
        expect(controller.supportedUpscalers, isEmpty);
        expect(controller.upscaler, isNull);
        expect(
          c.read(playerSettingsProvider).upscaler,
          'anime4k_a_fast',
          reason: 'kept for a device that supports it',
        );
      });

      test('switching applies right away and persists; off turns it off', () async {
        await setUpWith(supportedUpscalers: [anime4k]);
        await controller.open('alpha', 'm1');

        await controller.setUpscaler(anime4k);
        expect(backend.upscaler, anime4k);
        expect(c.read(playerSettingsProvider).upscaler, 'anime4k_a_fast');

        await controller.setUpscaler(null);
        expect(backend.upscaler, isNull);
        expect(c.read(playerSettingsProvider).upscaler, isNull);
        expect(backend.calls.where((call) => call.startsWith('upscaler')), ['upscaler:anime4k_a_fast', 'upscaler:off']);
      });

      test('a failing upscaler is turned off and reported; playback is not failed', () async {
        await setUpWith(prefs: {AppPreferences.videoPlayerUpscaler: 'anime4k_a_fast'}, supportedUpscalers: [anime4k]);
        await controller.open('alpha', 'm1');
        final failures = <Upscaler>[];
        controller.upscalerFailures.listen(failures.add);

        backend.failUpscaler();
        await pumpEventQueue();

        expect(failures, [anime4k]);
        expect(c.read(playerSettingsProvider).upscaler, isNull);
        expect(c.read(appPreferencesProvider).getString(AppPreferences.videoPlayerUpscaler), isNull);
        expect(controller.upscaler, isNull);
        expect(c.read(playerControllerProvider)!.failure, isNull);
        expect(backend.disposed, isFalse);
      });
    });
  });
}
