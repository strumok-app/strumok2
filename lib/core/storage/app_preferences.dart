import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_preferences.g.dart';

final _log = Logger('AppPreferences');

/// Typed access to persisted settings (spec-09 key names).
class AppPreferences {
  final SharedPreferencesWithCache _prefs;

  AppPreferences(this._prefs);

  static Future<AppPreferences> create() async =>
      AppPreferences(await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions()));

  static const ffiSupplierBundleInfo = 'ffi_supplier_bundle_info';
  static const suppliersOrder = 'suppliers_order';
  static const selectedContentLanguage = 'selected_content_language';
  static const selectedContentType = 'selected_content_type';
  static const selectedContentSuppliers = 'selected_content_suppliers';
  static const searchHistory = 'search_history';
  static const profiles = 'profiles';
  static const activeProfileId = 'active_profile_id';
  static const profileAskOnStartup = 'profile_ask_on_startup';
  static const offlineMode = 'offline_mode';
  static const offlineDownloadsDirectory = 'offline_downloads_directory';
  static const downloadsMaxParallel = 'downloads_max_parallel';
  static const downloadsBatteryPromptShown = 'downloads_battery_prompt_shown';
  static const userLanguage = 'user_language';
  static const themeBrightness = 'theme_brightness';
  static const themeColorScheme = 'theme_color_scheme';
  static const volume = 'volume';
  static const videoPlayerSubtitlesSize = 'video_player_subtitles_size';
  static const videoPlayerShuffleMode = 'video_player_setting_shuffle_mode';
  static const videoPlayerEndsAction = 'video_player_setting_ends_action';
  static const videoPlayerStartFrom = 'video_player_setting_start_from';
  static const videoPlayerFixedPosition = 'video_player_setting_fixed_position';
  static const videoPlayerEqualizerBands = 'video_player_equalizer_bands';
  static const videoPlayerVolumeNormalization = 'video_player_volume_normalization';
  static const videoPlayerDynamicCompression = 'video_player_dynamic_compression';
  static const floatingVideoPlayerEnabled = 'floating_video_player_enabled';
  static const mangaReaderBackground = 'manga_reader_background';
  static const mangaReaderMode = 'manga_reader_mode';
  static const mangaReaderAutoCrop = 'manga_reader_auto_crop';

  static String profileSearchHistory(String profileId) => '$searchHistory.$profileId';
  static const ffiUpdateLastCheck = 'ffi_update_last_check';
  static const ffiUpdateLatestInfo = 'ffi_update_latest_info';
  static const ffiUpdateNotifiedVersion = 'ffi_update_notified_version';
  static const appUpdateLastCheck = 'app_update_last_check';
  static const appUpdateLatestRelease = 'app_update_latest_release';
  static const appUpdateNotifiedVersion = 'app_update_notified_version';

  static String supplierEnabled(String supplier) => 'suppliers.$supplier.enabled';
  static String supplierChannels(String supplier) => 'suppliers.$supplier.channels';

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  double? getDouble(String key) => _prefs.getDouble(key);
  Future<void> setDouble(String key, double value) => _prefs.setDouble(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  List<String>? getStringList(String key) => _prefs.getStringList(key);
  Future<void> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  Map<String, Object?>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (e) {
      _log.warning('Invalid JSON in $key', e);
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, Object?> value) => _prefs.setString(key, jsonEncode(value));

  DateTime? getDateTime(String key) {
    final millis = _prefs.getInt(key);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setDateTime(String key, DateTime value) => _prefs.setInt(key, value.millisecondsSinceEpoch);
}

@Riverpod(keepAlive: true)
AppPreferences appPreferences(Ref ref) =>
    throw UnimplementedError('appPreferencesProvider must be overridden in main()');

/// Overridable clock for update-check throttling.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
