/// Signed-in Firebase user of a profile (spec-04 §4.2). [uid] keys `/collection/{uid}` (spec-03 §3.1).
final class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const AppUser({required this.uid, this.displayName, this.email, this.photoUrl});

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.email == email &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, displayName, email, photoUrl);
}

/// Google OAuth tokens exchanged for a Firebase credential.
typedef GoogleTokens = ({String? idToken, String? accessToken});

sealed class AuthException implements Exception {
  const AuthException();
}

/// The user closed the consent screen or cancelled the flow; not an error to report.
final class AuthCancelledException extends AuthException {
  const AuthCancelledException();
}

/// Accounts are not configured in this build (no `FIREBASE` define) or the platform has no sign-in.
final class AuthUnavailableException extends AuthException {
  const AuthUnavailableException();
}

/// Pairing code rejected by `exchangecodefortoken` (wrong or expired).
final class InvalidPairingCodeException extends AuthException {
  const InvalidPairingCodeException();
}

/// Another profile on this device is already linked to the same account (spec-05 §5.2).
final class AccountAlreadyLinkedException extends AuthException {
  final String profileId;

  const AccountAlreadyLinkedException(this.profileId);
}

/// Network/server failure; [cause] is logged, the UI shows a generic message.
final class AuthFailedException extends AuthException {
  final Object cause;

  const AuthFailedException(this.cause);

  @override
  String toString() => 'AuthFailedException: $cause';
}
