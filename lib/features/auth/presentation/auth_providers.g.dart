// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// From the `FIREBASE` define; null disables accounts and sync (e.g. builds without secrets, tests).

@ProviderFor(firebaseOptions)
final firebaseOptionsProvider = FirebaseOptionsProvider._();

/// From the `FIREBASE` define; null disables accounts and sync (e.g. builds without secrets, tests).

final class FirebaseOptionsProvider extends $FunctionalProvider<FirebaseOptions?, FirebaseOptions?, FirebaseOptions?>
    with $Provider<FirebaseOptions?> {
  /// From the `FIREBASE` define; null disables accounts and sync (e.g. builds without secrets, tests).
  FirebaseOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseOptionsHash();

  @$internal
  @override
  $ProviderElement<FirebaseOptions?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  FirebaseOptions? create(Ref ref) {
    return firebaseOptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseOptions? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<FirebaseOptions?>(value));
  }
}

String _$firebaseOptionsHash() => r'02bdbfbf91551e8f8b84d952225e6fcad8f473d4';

@ProviderFor(accountsAvailable)
final accountsAvailableProvider = AccountsAvailableProvider._();

final class AccountsAvailableProvider extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  AccountsAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountsAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountsAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return accountsAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$accountsAvailableHash() => r'afbd11e91ff350d6e7b44071ebd80b3b9bfe5da4';

@ProviderFor(profileFirebaseApps)
final profileFirebaseAppsProvider = ProfileFirebaseAppsProvider._();

final class ProfileFirebaseAppsProvider
    extends $FunctionalProvider<ProfileFirebaseApps?, ProfileFirebaseApps?, ProfileFirebaseApps?>
    with $Provider<ProfileFirebaseApps?> {
  ProfileFirebaseAppsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileFirebaseAppsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileFirebaseAppsHash();

  @$internal
  @override
  $ProviderElement<ProfileFirebaseApps?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ProfileFirebaseApps? create(Ref ref) {
    return profileFirebaseApps(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileFirebaseApps? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<ProfileFirebaseApps?>(value));
  }
}

String _$profileFirebaseAppsHash() => r'0f48834a7c058df217a45beb2f5cdd99fa9f770b';

/// Creates a profile's auth session in its own Firebase app; null when accounts are unavailable. Overridden in tests.

@ProviderFor(profileAuthFactory)
final profileAuthFactoryProvider = ProfileAuthFactoryProvider._();

/// Creates a profile's auth session in its own Firebase app; null when accounts are unavailable. Overridden in tests.

final class ProfileAuthFactoryProvider
    extends $FunctionalProvider<ProfileAuthFactory?, ProfileAuthFactory?, ProfileAuthFactory?>
    with $Provider<ProfileAuthFactory?> {
  /// Creates a profile's auth session in its own Firebase app; null when accounts are unavailable. Overridden in tests.
  ProfileAuthFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileAuthFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileAuthFactoryHash();

  @$internal
  @override
  $ProviderElement<ProfileAuthFactory?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ProfileAuthFactory? create(Ref ref) {
    return profileAuthFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileAuthFactory? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<ProfileAuthFactory?>(value));
  }
}

String _$profileAuthFactoryHash() => r'8f569e03594a17ce6b5fd8e697de724e74a90970';

/// Auth session of a profile (spec-05 §5.2); null when accounts are unavailable.

@ProviderFor(profileAuth)
final profileAuthProvider = ProfileAuthFamily._();

/// Auth session of a profile (spec-05 §5.2); null when accounts are unavailable.

final class ProfileAuthProvider
    extends $FunctionalProvider<AsyncValue<ProfileAuth?>, ProfileAuth?, FutureOr<ProfileAuth?>>
    with $FutureModifier<ProfileAuth?>, $FutureProvider<ProfileAuth?> {
  /// Auth session of a profile (spec-05 §5.2); null when accounts are unavailable.
  ProfileAuthProvider._({required ProfileAuthFamily super.from, required String super.argument})
    : super(
        retry: null,
        name: r'profileAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileAuthHash();

  @override
  String toString() {
    return r'profileAuthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ProfileAuth?> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileAuth?> create(Ref ref) {
    final argument = this.argument as String;
    return profileAuth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileAuthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileAuthHash() => r'5680bb04a1b21e0beec4f2b7a241b8f260ed9b1a';

/// Auth session of a profile (spec-05 §5.2); null when accounts are unavailable.

final class ProfileAuthFamily extends $Family with $FunctionalFamilyOverride<FutureOr<ProfileAuth?>, String> {
  ProfileAuthFamily._()
    : super(
        retry: null,
        name: r'profileAuthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Auth session of a profile (spec-05 §5.2); null when accounts are unavailable.

  ProfileAuthProvider call(String profileId) => ProfileAuthProvider._(argument: profileId, from: this);

  @override
  String toString() => r'profileAuthProvider';
}

/// Native on Android phones/tablets, browser consent on desktop, none on TV (pairing code only, spec-04 §4.2).

@ProviderFor(googleSignInService)
final googleSignInServiceProvider = GoogleSignInServiceProvider._();

/// Native on Android phones/tablets, browser consent on desktop, none on TV (pairing code only, spec-04 §4.2).

final class GoogleSignInServiceProvider
    extends $FunctionalProvider<GoogleSignInService, GoogleSignInService, GoogleSignInService>
    with $Provider<GoogleSignInService> {
  /// Native on Android phones/tablets, browser consent on desktop, none on TV (pairing code only, spec-04 §4.2).
  GoogleSignInServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleSignInServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleSignInServiceHash();

  @$internal
  @override
  $ProviderElement<GoogleSignInService> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  GoogleSignInService create(Ref ref) {
    return googleSignInService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleSignInService value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<GoogleSignInService>(value));
  }
}

String _$googleSignInServiceHash() => r'397d873598c651671c55b7a1e7ff538c6194493b';

@ProviderFor(googleSignInAvailable)
final googleSignInAvailableProvider = GoogleSignInAvailableProvider._();

final class GoogleSignInAvailableProvider extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  GoogleSignInAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleSignInAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleSignInAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return googleSignInAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$googleSignInAvailableHash() => r'1fdd4bc5fd590d64d1809e8b79d2f7e6a8d8a9bd';

@ProviderFor(pairingApi)
final pairingApiProvider = PairingApiProvider._();

final class PairingApiProvider extends $FunctionalProvider<PairingApi?, PairingApi?, PairingApi?>
    with $Provider<PairingApi?> {
  PairingApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pairingApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pairingApiHash();

  @$internal
  @override
  $ProviderElement<PairingApi?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  PairingApi? create(Ref ref) {
    return pairingApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PairingApi? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<PairingApi?>(value));
  }
}

String _$pairingApiHash() => r'a222050cf5578bcc2de0132dab65a965f706e91d';

/// Signed-in user of a profile. Firebase is only started for linked profiles; the first event is the restored
/// session. Cached account details on the profile follow the session, and a lost session unlinks the profile.

@ProviderFor(authUser)
final authUserProvider = AuthUserFamily._();

/// Signed-in user of a profile. Firebase is only started for linked profiles; the first event is the restored
/// session. Cached account details on the profile follow the session, and a lost session unlinks the profile.

final class AuthUserProvider extends $FunctionalProvider<AsyncValue<AppUser?>, AppUser?, Stream<AppUser?>>
    with $FutureModifier<AppUser?>, $StreamProvider<AppUser?> {
  /// Signed-in user of a profile. Firebase is only started for linked profiles; the first event is the restored
  /// session. Cached account details on the profile follow the session, and a lost session unlinks the profile.
  AuthUserProvider._({required AuthUserFamily super.from, required String super.argument})
    : super(
        retry: null,
        name: r'authUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authUserHash();

  @override
  String toString() {
    return r'authUserProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AppUser?> $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<AppUser?> create(Ref ref) {
    final argument = this.argument as String;
    return authUser(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AuthUserProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$authUserHash() => r'56e065ca640e994cb16df171d837a690e6d866d6';

/// Signed-in user of a profile. Firebase is only started for linked profiles; the first event is the restored
/// session. Cached account details on the profile follow the session, and a lost session unlinks the profile.

final class AuthUserFamily extends $Family with $FunctionalFamilyOverride<Stream<AppUser?>, String> {
  AuthUserFamily._()
    : super(
        retry: null,
        name: r'authUserProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Signed-in user of a profile. Firebase is only started for linked profiles; the first event is the restored
  /// session. Cached account details on the profile follow the session, and a lost session unlinks the profile.

  AuthUserProvider call(String profileId) => AuthUserProvider._(argument: profileId, from: this);

  @override
  String toString() => r'authUserProvider';
}

@ProviderFor(activeAuthUser)
final activeAuthUserProvider = ActiveAuthUserProvider._();

final class ActiveAuthUserProvider
    extends $FunctionalProvider<AsyncValue<AppUser?>, AsyncValue<AppUser?>, AsyncValue<AppUser?>>
    with $Provider<AsyncValue<AppUser?>> {
  ActiveAuthUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAuthUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAuthUserHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<AppUser?>> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  AsyncValue<AppUser?> create(Ref ref) {
    return activeAuthUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AppUser?> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AsyncValue<AppUser?>>(value));
  }
}

String _$activeAuthUserHash() => r'04a67915e9feab186841e68e6e09cd92ab7f4f36';

/// Account actions for a profile (spec-04 §4.2–4.4, spec-05 §5.4). Methods throw [AuthException]s.

@ProviderFor(AccountController)
final accountControllerProvider = AccountControllerProvider._();

/// Account actions for a profile (spec-04 §4.2–4.4, spec-05 §5.4). Methods throw [AuthException]s.
final class AccountControllerProvider extends $NotifierProvider<AccountController, void> {
  /// Account actions for a profile (spec-04 §4.2–4.4, spec-05 §5.4). Methods throw [AuthException]s.
  AccountControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountControllerHash();

  @$internal
  @override
  AccountController create() => AccountController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<void>(value));
  }
}

String _$accountControllerHash() => r'eb749094918d432741fb0ca7138e115a41227c40';

/// Account actions for a profile (spec-04 §4.2–4.4, spec-05 §5.4). Methods throw [AuthException]s.

abstract class _$AccountController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<void, void>, void, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
