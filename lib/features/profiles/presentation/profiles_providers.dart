import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/platform/app_paths.dart';
import '../../../core/storage/app_preferences.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/profile.dart';

part 'profiles_providers.g.dart';

final _log = Logger('Profiles');

/// Per-profile data dir (`<appSupport>/profiles/<id>`): local collection etc.
Directory profileDirectory(AppPaths paths, String profileId) =>
    Directory(p.join(paths.support.path, 'profiles', profileId));

/// Device-wide list of profiles (spec-05 §5.1). The first launch creates a default profile.
@Riverpod(keepAlive: true)
class Profiles extends _$Profiles {
  AppPreferences get _prefs => ref.read(appPreferencesProvider);

  @override
  List<Profile> build() {
    final raw = _prefs.getString(AppPreferences.profiles);
    if (raw != null) {
      try {
        final profiles = [
          for (final e in jsonDecode(raw) as List) Profile.fromJson((e as Map).cast<String, Object?>()),
        ];
        if (profiles.isNotEmpty) return profiles;
      } catch (e) {
        _log.severe('Invalid stored profiles', e);
      }
    }
    final isUk = ref.read(appLocaleProvider).languageCode == 'uk';
    final initial = [_newProfile(isUk ? 'Основний' : 'Main', profileColors.first)];
    unawaited(_persist(initial));
    return initial;
  }

  Profile _newProfile(String name, int color) =>
      Profile(id: newProfileId(), name: name.trim(), colorSeed: color, createdAt: ref.read(clockProvider)());

  Future<void> _persist(List<Profile> profiles) =>
      _prefs.setString(AppPreferences.profiles, jsonEncode([for (final p in profiles) p.toJson()]));

  Future<Profile> create(String name, int color) async {
    final profile = _newProfile(name, color);
    state = [...state, profile];
    await _persist(state);
    return profile;
  }

  Future<void> update(String id, {String? name, int? color}) async {
    state = [for (final p in state) p.id == id ? p.copyWith(name: name?.trim(), colorSeed: color) : p];
    await _persist(state);
  }

  /// Links [id] to the signed-in [user]; a uid may be linked to one profile only (spec-05 §5.2).
  Future<void> linkAccount(String id, AppUser user) async {
    final owner = state.where((p) => p.id != id && p.firebaseUid == user.uid).firstOrNull;
    if (owner != null) throw AccountAlreadyLinkedException(owner.id);
    await _updateProfile(id, (p) => p.withAccount(uid: user.uid, name: _accountName(user), photoUrl: user.photoUrl));
  }

  Future<void> unlinkAccount(String id) => _updateProfile(id, (p) => p.withoutAccount());

  /// Keeps cached account details current; a lost session (null user) unlinks the profile.
  Future<void> syncAccount(String id, AppUser? user) async {
    final profile = state.where((p) => p.id == id).firstOrNull;
    if (profile == null || !profile.isLinked) return;
    if (user == null) return unlinkAccount(id);
    if (user.uid != profile.firebaseUid) return;
    final name = _accountName(user);
    if (name == profile.accountName && user.photoUrl == profile.accountPhotoUrl) return;
    await _updateProfile(id, (p) => p.withAccount(uid: user.uid, name: name, photoUrl: user.photoUrl));
  }

  static String? _accountName(AppUser user) => user.displayName ?? user.email;

  Future<void> _updateProfile(String id, Profile Function(Profile) update) async {
    state = [for (final p in state) p.id == id ? update(p) : p];
    await _persist(state);
  }

  /// Removes the profile and its local data; Firebase data is never touched (spec-05 §5.4).
  /// The active profile cannot be deleted (switch first), nor the last one.
  Future<void> delete(String id) async {
    // Same resolution as [ActiveProfile]; reading that provider here would be circular.
    final storedActive = _prefs.getString(AppPreferences.activeProfileId);
    final activeId = state.any((p) => p.id == storedActive) ? storedActive : state.first.id;
    if (state.length <= 1 || activeId == id) return;
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
    await _persist(state);
    await _prefs.remove(AppPreferences.profileSearchHistory(id));
    // Its own signed-in session and database cache (spec-05 §5.2).
    await ref.read(profileFirebaseAppsProvider)?.delete(id);
    final dir = profileDirectory(ref.read(appPathsProvider), id);
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (e) {
      _log.warning('Could not delete ${dir.path}', e);
    }
  }
}

@Riverpod(keepAlive: true)
class ActiveProfile extends _$ActiveProfile {
  @override
  Profile build() {
    final profiles = ref.watch(profilesProvider);
    final id = ref.read(appPreferencesProvider).getString(AppPreferences.activeProfileId);
    return profiles.where((p) => p.id == id).firstOrNull ?? profiles.first;
  }

  Future<void> select(String id) async {
    await ref.read(appPreferencesProvider).setString(AppPreferences.activeProfileId, id);
    ref.invalidateSelf();
  }
}

/// Only the id: consumers that hold per-profile resources must not rebuild on rename.
@Riverpod(keepAlive: true)
String activeProfileId(Ref ref) => ref.watch(activeProfileProvider.select((p) => p.id));

@Riverpod(keepAlive: true)
class ProfileAskOnStartup extends _$ProfileAskOnStartup {
  @override
  bool build() => ref.read(appPreferencesProvider).getBool(AppPreferences.profileAskOnStartup) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(appPreferencesProvider).setBool(AppPreferences.profileAskOnStartup, value);
  }
}

/// True until a profile is picked in this app run, when the picker applies (≥ 2 profiles, spec-05 §5.4).
@Riverpod(keepAlive: true)
class ProfilePickPending extends _$ProfilePickPending {
  @override
  bool build() => ref.read(profilesProvider).length >= 2 && ref.read(profileAskOnStartupProvider);

  void done() => state = false;
}
