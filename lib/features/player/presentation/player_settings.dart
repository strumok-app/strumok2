import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/storage/app_preferences.dart';
import '../domain/equalizer.dart';
import '../domain/player_preferences.dart';
import '../domain/player_session.dart';
import '../domain/upscaling.dart';

part 'player_settings.g.dart';

/// Persisted player settings (spec-09 keys, enums stored by `.name`).
@Riverpod(keepAlive: true)
class PlayerSettings extends _$PlayerSettings {
  AppPreferences get _prefs => ref.read(appPreferencesProvider);

  @override
  PlayerPreferences build() {
    final prefs = _prefs;
    return PlayerPreferences(
      startFrom:
          StartFrom.values.asNameMap()[prefs.getString(AppPreferences.videoPlayerStartFrom)] ??
          StartFrom.fromRemembered,
      fixedPosition: prefs.getInt(AppPreferences.videoPlayerFixedPosition) ?? 0,
      endAction:
          EndAction.values.asNameMap()[prefs.getString(AppPreferences.videoPlayerEndsAction)] ?? EndAction.playNext,
      shuffle: prefs.getBool(AppPreferences.videoPlayerShuffleMode) ?? false,
      equalizer: parseEqualizerGains(
        bandsCsv: prefs.getString(AppPreferences.videoPlayerEqualizerBands),
        preamp: prefs.getDouble(AppPreferences.videoPlayerEqualizerPreamp),
      ),
      volumeNormalization: prefs.getBool(AppPreferences.videoPlayerVolumeNormalization) ?? false,
      dynamicCompression: prefs.getBool(AppPreferences.videoPlayerDynamicCompression) ?? false,
      floatingPlayer: prefs.getBool(AppPreferences.floatingVideoPlayerEnabled) ?? true,
      upscaler: prefs.getString(AppPreferences.videoPlayerUpscaler),
    );
  }

  Future<void> setStartFrom(StartFrom value) async {
    state = state.copyWith(startFrom: value);
    await _prefs.setString(AppPreferences.videoPlayerStartFrom, value.name);
  }

  Future<void> setFixedPosition(int seconds) async {
    final value = seconds < 0 ? 0 : seconds;
    state = state.copyWith(fixedPosition: value);
    await _prefs.setInt(AppPreferences.videoPlayerFixedPosition, value);
  }

  Future<void> setEndAction(EndAction value) async {
    state = state.copyWith(endAction: value);
    await _prefs.setString(AppPreferences.videoPlayerEndsAction, value.name);
  }

  Future<void> setShuffle(bool value) async {
    state = state.copyWith(shuffle: value);
    await _prefs.setBool(AppPreferences.videoPlayerShuffleMode, value);
  }

  Future<void> setFloatingPlayer(bool value) async {
    state = state.copyWith(floatingPlayer: value);
    await _prefs.setBool(AppPreferences.floatingVideoPlayerEnabled, value);
  }

  Future<void> setEqualizer(EqualizerGains gains) async {
    final value = gains.clamped();
    state = state.copyWith(equalizer: value);
    await _prefs.setString(AppPreferences.videoPlayerEqualizerBands, formatEqualizerBands(value.bands));
    await _prefs.setDouble(AppPreferences.videoPlayerEqualizerPreamp, value.preamp);
  }

  Future<void> setVolumeNormalization(bool value) async {
    state = state.copyWith(volumeNormalization: value);
    await _prefs.setBool(AppPreferences.videoPlayerVolumeNormalization, value);
  }

  /// Null turns upscaling off.
  Future<void> setUpscaler(String? id) async {
    state = state.copyWith(upscaler: id, clearUpscaler: id == null);
    if (id == null) {
      await _prefs.remove(AppPreferences.videoPlayerUpscaler);
    } else {
      await _prefs.setString(AppPreferences.videoPlayerUpscaler, id);
    }
  }

  Future<void> setDynamicCompression(bool value) async {
    state = state.copyWith(dynamicCompression: value);
    await _prefs.setBool(AppPreferences.videoPlayerDynamicCompression, value);
  }
}

String startFromLabel(AppLocalizations l10n, StartFrom value) => switch (value) {
  StartFrom.fromRemembered => l10n.playerStartFromRemembered,
  StartFrom.fromBeginning => l10n.playerStartFromBeginning,
  StartFrom.fromFixedPosition => l10n.playerStartFromFixed,
};

String endActionLabel(AppLocalizations l10n, EndAction value) => switch (value) {
  EndAction.playNext => l10n.playerOnEndNext,
  EndAction.playAgain => l10n.playerOnEndAgain,
  EndAction.doNothing => l10n.playerOnEndNothing,
};

/// Null (gains matching no preset) is "Custom".
String equalizerPresetLabel(AppLocalizations l10n, EqualizerPreset? preset) => switch (preset) {
  EqualizerPreset.reset => l10n.playerEqualizerOff,
  EqualizerPreset.clearDialogue => l10n.playerEqualizerClearDialogue,
  EqualizerPreset.cinema => l10n.playerEqualizerCinema,
  EqualizerPreset.night => l10n.playerEqualizerNight,
  EqualizerPreset.action => l10n.playerEqualizerAction,
  null => l10n.playerEqualizerCustom,
};

/// Null is off; otherwise e.g. `Anime4K · Mode A (fast)`.
String upscalerLabel(AppLocalizations l10n, Upscaler? upscaler) => upscaler == null
    ? l10n.playerUpscalingOff
    : l10n.playerUpscalerValue(upscalerFamilyLabel(l10n, upscaler.family), upscalerVariantLabel(l10n, upscaler));

String upscalerFamilyLabel(AppLocalizations l10n, UpscalerFamily family) => switch (family) {
  UpscalerFamily.fsrcnnx => l10n.playerUpscalerFamilyFsrcnnx,
  UpscalerFamily.ravu => l10n.playerUpscalerFamilyRavu,
  UpscalerFamily.nnedi3 => l10n.playerUpscalerFamilyNnedi3,
  UpscalerFamily.anime4k => l10n.playerUpscalerFamilyAnime4k,
};

String upscalerVariantLabel(AppLocalizations l10n, Upscaler upscaler) => switch (upscaler.id) {
  'fsrcnnx_8' => l10n.playerUpscalerFsrcnnx8,
  'fsrcnnx_16' => l10n.playerUpscalerFsrcnnx16,
  'ravu_lite_r4' => l10n.playerUpscalerRavuLite,
  'ravu_zoom_r3' => l10n.playerUpscalerRavuZoom,
  'nnedi3_64' => l10n.playerUpscalerNnedi3_64,
  'nnedi3_128' => l10n.playerUpscalerNnedi3_128,
  'anime4k_a_fast' => l10n.playerUpscalerAnime4kAFast,
  'anime4k_a_hq' => l10n.playerUpscalerAnime4kAHq,
  'anime4k_b_hq' => l10n.playerUpscalerAnime4kBHq,
  'anime4k_c_hq' => l10n.playerUpscalerAnime4kCHq,
  _ => upscaler.id,
};

String upscalerCostLabel(AppLocalizations l10n, UpscalerCost cost) => switch (cost) {
  UpscalerCost.light => l10n.playerUpscalerCostLight,
  UpscalerCost.medium => l10n.playerUpscalerCostMedium,
  UpscalerCost.heavy => l10n.playerUpscalerCostHeavy,
};

String speedLabel(AppLocalizations l10n, double speed) =>
    speed == 1 ? l10n.playerSpeedNormal : l10n.playerSpeedValue(_number(speed));

String frequencyLabel(AppLocalizations l10n, int hertz) =>
    hertz >= 1000 ? l10n.playerKilohertz(_number(hertz / 1000)) : l10n.playerHertz('$hertz');

/// Compact band label for the equalizer graph, e.g. `170`, `1k`.
String frequencyShortLabel(AppLocalizations l10n, int hertz) =>
    hertz >= 1000 ? l10n.playerKilohertzShort(_number(hertz / 1000)) : '$hertz';

String gainLabel(AppLocalizations l10n, double decibels) => l10n.playerDecibels(
  '${decibels > 0
      ? '+'
      : decibels < 0
      ? '−'
      : ''}${_number(decibels.abs())}',
);

/// `2` rather than `2.0`; one decimal otherwise.
String _number(double value) => value == value.roundToDouble() ? '${value.round()}' : '$value';
