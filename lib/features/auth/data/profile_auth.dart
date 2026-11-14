import 'package:firebase_dart/firebase_dart.dart';

import '../domain/app_user.dart';

/// Firebase Auth session of one profile (spec-04, spec-05 §5.2).
abstract interface class ProfileAuth {
  /// Emits the current user first (once the persisted session is restored), then every change.
  Stream<AppUser?> userChanges();

  AppUser? get currentUser;

  Future<AppUser> signInWithGoogle(GoogleTokens tokens);

  Future<AppUser> signInWithCustomToken(String token);

  /// ID token of the signed-in user for authorized cloud function calls.
  Future<String> idToken();

  Future<void> signOut();
}

class FirebaseProfileAuth implements ProfileAuth {
  final FirebaseAuth _auth;

  FirebaseProfileAuth(this._auth);

  static AppUser? _map(User? user) => user == null
      ? null
      : AppUser(uid: user.uid, displayName: user.displayName, email: user.email, photoUrl: user.photoURL);

  @override
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser> signInWithGoogle(GoogleTokens tokens) => _signIn(
    () => _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: tokens.idToken, accessToken: tokens.accessToken),
    ),
  );

  @override
  Future<AppUser> signInWithCustomToken(String token) => _signIn(() => _auth.signInWithCustomToken(token));

  Future<AppUser> _signIn(Future<UserCredential> Function() signIn) async {
    try {
      final user = _map((await signIn()).user);
      if (user == null) throw StateError('Sign-in returned no user');
      return user;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthFailedException(e);
    }
  }

  @override
  Future<String> idToken() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailedException('Not signed in');
    return user.getIdToken();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
