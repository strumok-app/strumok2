import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/storage/app_preferences.dart';
import '../domain/equalizer.dart';
import '../domain/player_preferences.dart';
import '../domain/player_session.dart';

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
      equalizer: parseEqualizerBands(prefs.getString(AppPreferences.videoPlayerEqualizerBands)),
      floatingPlayer: prefs.getBool(AppPreferences.floatingVideoPlayerEnabled) ?? true,
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

  Future<void> setEqualizer(List<double> bands) async {
    final value = [for (final b in bands) b.clamp(-equalizerMaxGain, equalizerMaxGain).toDouble()];
    state = state.copyWith(equalizer: value);
    await _prefs.setString(AppPreferences.videoPlayerEqualizerBands, formatEqualizerBands(value));
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
  EqualizerPreset.max => l10n.playerEqualizerMax,
  null => l10n.playerEqualizerCustom,
};

String speedLabel(AppLocalizations l10n, double speed) =>
    speed == 1 ? l10n.playerSpeedNormal : l10n.playerSpeedValue(_number(speed));

String frequencyLabel(AppLocalizations l10n, int hertz) =>
    hertz >= 1000 ? l10n.playerKilohertz(_number(hertz / 1000)) : l10n.playerHertz('$hertz');

String gainLabel(AppLocalizations l10n, double decibels) => l10n.playerDecibels(
  '${decibels > 0
      ? '+'
      : decibels < 0
      ? '−'
      : ''}${_number(decibels.abs())}',
);

/// `2` rather than `2.0`; one decimal otherwise.
String _number(double value) => value == value.roundToDouble() ? '${value.round()}' : '$value';
