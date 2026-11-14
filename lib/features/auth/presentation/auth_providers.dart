import 'dart:io';

import 'package:firebase_dart/firebase_dart.dart' show FirebaseAuth, FirebaseOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config.dart';
import '../../../core/network/http_client.dart';
import '../../../core/platform/app_paths.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/platform/device_class.dart';
import '../../profiles/presentation/profiles_providers.dart';
import '../data/firebase_apps.dart';
import '../data/google_sign_in_service.dart';
import '../data/pairing_api.dart';
import '../data/profile_auth.dart';
import '../domain/app_user.dart';
import '../domain/pairing_code.dart';

part 'auth_providers.g.dart';

/// From the `FIREBASE` define; null disables accounts and sync (e.g. builds without secrets, tests).
@Riverpod(keepAlive: true)
FirebaseOptions? firebaseOptions(Ref ref) => parseFirebaseOptions(AppConfig.firebaseOptions);

@Riverpod(keepAlive: true)
bool accountsAvailable(Ref ref) => ref.watch(firebaseOptionsProvider) != null;

@Riverpod(keepAlive: true)
ProfileFirebaseApps? profileFirebaseApps(Ref ref) {
  final options = ref.watch(firebaseOptionsProvider);
  if (options == null) return null;
  return ProfileFirebaseApps(
    options: options,
    root: Directory(p.join(ref.watch(appPathsProvider).support.path, 'firebase')),
  );
}

typedef ProfileAuthFactory = Future<ProfileAuth> Function(String profileId);

/// Creates a profile's auth session in its own Firebase app; null when accounts are unavailable. Overridden in tests.
@Riverpod(keepAlive: true)
ProfileAuthFactory? profileAuthFactory(Ref ref) {
  final apps = ref.watch(profileFirebaseAppsProvider);
  if (apps == null) return null;
  return (profileId) async => FirebaseProfileAuth(FirebaseAuth.instanceFor(app: await apps.app(profileId)));
}

/// Auth session of a profile (spec-05 §5.2); null when accounts are unavailable.
@Riverpod(keepAlive: true)
Future<ProfileAuth?> profileAuth(Ref ref, String profileId) async {
  final create = ref.watch(profileAuthFactoryProvider);
  return create == null ? null : await create(profileId);
}

/// Native on Android phones/tablets, browser consent on desktop, none on TV (pairing code only, spec-04 §4.2).
@Riverpod(keepAlive: true)
GoogleSignInService googleSignInService(Ref ref) {
  if (!ref.watch(accountsAvailableProvider) || ref.watch(deviceClassProvider) == DeviceClass.tv) {
    return const UnavailableGoogleSignIn();
  }
  if (AppPlatform.current == AppPlatform.android) return AndroidGoogleSignIn();
  final clientId = DesktopGoogleSignIn.parseClientId(AppConfig.googleAuthClient);
  if (clientId == null) return const UnavailableGoogleSignIn();
  return DesktopGoogleSignIn(clientId: clientId, client: ref.watch(httpClientProvider));
}

@Riverpod(keepAlive: true)
bool googleSignInAvailable(Ref ref) => ref.watch(googleSignInServiceProvider) is! UnavailableGoogleSignIn;

@Riverpod(keepAlive: true)
PairingApi? pairingApi(Ref ref) {
  if (!ref.watch(accountsAvailableProvider) || AppConfig.cloudFunDomain.isEmpty) return null;
  return PairingApi(client: ref.watch(httpClientProvider), domain: AppConfig.cloudFunDomain);
}

/// Signed-in user of a profile. Firebase is only started for linked profiles; the first event is the restored
/// session. Cached account details on the profile follow the session, and a lost session unlinks the profile.
@Riverpod(keepAlive: true)
Stream<AppUser?> authUser(Ref ref, String profileId) async* {
  final linked = ref.watch(
    profilesProvider.select((profiles) => profiles.any((profile) => profile.id == profileId && profile.isLinked)),
  );
  ProfileAuth? auth;
  if (linked) auth = await ref.watch(profileAuthProvider(profileId).future);
  if (auth == null) {
    yield null;
    return;
  }
  await for (final user in auth.userChanges()) {
    await ref.read(profilesProvider.notifier).syncAccount(profileId, user);
    yield user;
  }
}

@Riverpod(keepAlive: true)
AsyncValue<AppUser?> activeAuthUser(Ref ref) => ref.watch(authUserProvider(ref.watch(activeProfileIdProvider)));

/// Account actions for a profile (spec-04 §4.2–4.4, spec-05 §5.4). Methods throw [AuthException]s.
@Riverpod(keepAlive: true)
class AccountController extends _$AccountController {
  @override
  void build() {}

  Future<ProfileAuth> _auth(String profileId) async {
    final auth = await ref.read(profileAuthProvider(profileId).future);
    return auth ?? (throw const AuthUnavailableException());
  }

  Future<void> signInWithGoogle(String profileId) async {
    final tokens = await ref.read(googleSignInServiceProvider).signIn();
    final auth = await _auth(profileId);
    await _link(profileId, auth, await auth.signInWithGoogle(tokens));
  }

  /// [input] is validated with [normalizePairingCode]; a rejected code throws [InvalidPairingCodeException].
  Future<void> signInWithPairingCode(String profileId, String input) async {
    final code = normalizePairingCode(input) ?? (throw const InvalidPairingCodeException());
    final api = ref.read(pairingApiProvider) ?? (throw const AuthUnavailableException());
    final token = await api.exchangeCode(code);
    final auth = await _auth(profileId);
    await _link(profileId, auth, await auth.signInWithCustomToken(token));
  }

  Future<void> _link(String profileId, ProfileAuth auth, AppUser user) async {
    try {
      await ref.read(profilesProvider.notifier).linkAccount(profileId, user);
    } on AccountAlreadyLinkedException {
      await auth.signOut();
      rethrow;
    }
  }

  /// Firebase + platform sign-out; the profile keeps its local collection.
  Future<void> signOut(String profileId) async {
    await (await ref.read(profileAuthProvider(profileId).future))?.signOut();
    await ref.read(googleSignInServiceProvider).signOut();
    await ref.read(profilesProvider.notifier).unlinkAccount(profileId);
  }

  /// Code for logging in a TV as the active profile's account.
  Future<String> generatePairingCode() async {
    final api = ref.read(pairingApiProvider) ?? (throw const AuthUnavailableException());
    final auth = await _auth(ref.read(activeProfileIdProvider));
    return api.generateCode(await auth.idToken());
  }
}
