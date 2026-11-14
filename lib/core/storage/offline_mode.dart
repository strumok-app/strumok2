import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_preferences.dart';

part 'offline_mode.g.dart';

/// Global offline-mode switch (spec-08 §8.4, spec-09 key `offline_mode`). While on, the collection is local-only
/// and is reconciled with Firebase when it is turned off again (spec-03 §3.6).
@Riverpod(keepAlive: true)
class OfflineMode extends _$OfflineMode {
  @override
  bool build() => ref.read(appPreferencesProvider).getBool(AppPreferences.offlineMode) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(appPreferencesProvider).setBool(AppPreferences.offlineMode, value);
  }
}
