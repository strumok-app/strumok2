import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/app_user.dart';

final _log = Logger('GoogleSignIn');

/// Scopes requested by the legacy app (spec-04 §4.2).
const googleScopes = [
  'https://www.googleapis.com/auth/userinfo.profile',
  'https://www.googleapis.com/auth/userinfo.email',
];

/// Platform Google account consent returning tokens for a Firebase credential (spec-04 §4.2).
abstract interface class GoogleSignInService {
  /// Throws [AuthCancelledException] when the user backs out.
  Future<GoogleTokens> signIn();

  Future<void> signOut();
}

/// Android TV (pairing code only) or a build without the OAuth client.
class UnavailableGoogleSignIn implements GoogleSignInService {
  const UnavailableGoogleSignIn();

  @override
  Future<GoogleTokens> signIn() => Future.error(const AuthUnavailableException());

  @override
  Future<void> signOut() async {}
}

/// Desktop: installed-app consent in the system browser with a loopback redirect.
class DesktopGoogleSignIn implements GoogleSignInService {
  final ClientId clientId;
  final http.Client client;

  DesktopGoogleSignIn({required this.clientId, required this.client});

  /// Parses the `GOOGLE_AUTH` define; null when absent or invalid (the value is never logged).
  static ClientId? parseClientId(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return ClientId.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      _log.severe('GOOGLE_AUTH define is not a valid OAuth client JSON');
      return null;
    }
  }

  @override
  Future<GoogleTokens> signIn() async {
    final credentials = await obtainAccessCredentialsViaUserConsent(clientId, googleScopes, client, (url) async {
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        _log.warning('Could not open the browser for Google consent');
      }
    });
    return (idToken: credentials.idToken, accessToken: credentials.accessToken.data);
  }

  // The browser keeps its Google session; nothing to revoke locally (legacy behavior).
  @override
  Future<void> signOut() async {}
}

/// Android phone/tablet: native Google Sign-In (OAuth client from google-services.json).
class AndroidGoogleSignIn implements GoogleSignInService {
  Future<void>? _initialized;

  Future<void> _init() => _initialized ??= GoogleSignIn.instance.initialize();

  @override
  Future<GoogleTokens> signIn() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: googleScopes);
      final authorization = await account.authorizationClient.authorizeScopes(googleScopes);
      return (idToken: account.authentication.idToken, accessToken: authorization.accessToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelledException();
      }
      throw AuthFailedException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      _log.warning('Google disconnect failed', e);
    }
  }
}
