import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/features/auth/data/google_sign_in_service.dart';
import 'package:strumok/features/auth/data/pairing_api.dart';
import 'package:strumok/features/auth/data/profile_auth.dart';
import 'package:strumok/features/auth/domain/app_user.dart';
import 'package:strumok/features/auth/presentation/auth_providers.dart';
import 'package:strumok/features/collection/data/collection_repository.dart';
import 'package:strumok/features/collection/data/remote_collection.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';

/// Firebase auth session of one profile: replays the current user to new listeners like firebase_dart does.
class FakeProfileAuth implements ProfileAuth {
  final FakeAuthBackend backend;
  final _changes = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _user;

  FakeProfileAuth(this.backend, [this._user]);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> userChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  void _set(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<AppUser> signInWithGoogle(GoogleTokens tokens) async {
    final user = backend.usersByIdToken[tokens.idToken] ?? (throw const AuthFailedException('unknown token'));
    _set(user);
    return user;
  }

  @override
  Future<AppUser> signInWithCustomToken(String token) async {
    final user = backend.usersByCustomToken[token] ?? (throw const AuthFailedException('bad custom token'));
    _set(user);
    return user;
  }

  @override
  Future<String> idToken() async => 'id-token-${_user?.uid ?? (throw const AuthFailedException('signed out'))}';

  @override
  Future<void> signOut() async => _set(null);
}

class FakeAuthBackend {
  final usersByIdToken = <String?, AppUser>{};
  final usersByCustomToken = <String, AppUser>{};

  /// Pairing codes accepted by the fake `exchangecodefortoken` → custom token.
  final codes = <String, String>{};

  /// Code returned by the fake `generatecode` per uid.
  final generatedCodes = <String, String>{};
  final sessions = <String, FakeProfileAuth>{};
  final requests = <http.Request>[];

  FakeProfileAuth session(String profileId) => sessions.putIfAbsent(profileId, () => FakeProfileAuth(this));

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    if (request.url.host.startsWith('exchangecodefortoken-')) {
      final token = codes[request.bodyFields['code']];
      return token == null ? http.Response('invalid', 404) : http.Response(jsonEncode({'token': token}), 200);
    }
    if (request.url.host.startsWith('generatecode-')) {
      final idToken = request.headers['Authorization']?.replaceFirst('Bearer id-token-', '');
      final code = generatedCodes[idToken];
      return code == null ? http.Response('unauthorized', 401) : http.Response(jsonEncode({'code': code}), 200);
    }
    return http.Response('', 404);
  });
}

class FakeGoogleSignIn implements GoogleSignInService {
  String? idToken;
  Object? error;
  var signOuts = 0;

  FakeGoogleSignIn({this.idToken});

  @override
  Future<GoogleTokens> signIn() async {
    if (error case final error?) throw error;
    return (idToken: idToken, accessToken: 'access');
  }

  @override
  Future<void> signOut() async => signOuts++;
}

/// In-memory `/collection/{uid}`. Writes apply at once; the server ack can be held back ([holdAcks]) or fail.
class FakeRemoteCollection implements RemoteCollection {
  final items = <String, CollectionItem>{};
  final _changes = StreamController<RemoteCollectionChange>.broadcast(sync: true);
  final writes = <String, Map<String, Object?>>{};
  final removed = <String>[];
  var holdAcks = false;
  var failWrites = false;
  final _heldAcks = <Completer<void>>[];
  var closed = false;

  @override
  Future<Map<String, CollectionItem>> fetchAll() async => {...items};

  @override
  Stream<RemoteCollectionChange> changes() async* {
    for (final item in [...items.values]) {
      yield (item: item, removed: false);
    }
    yield* _changes.stream;
  }

  /// A change made by another device.
  void remoteUpsert(CollectionItem item) {
    items[item.key] = item;
    _changes.add((item: item, removed: false));
  }

  /// Raw event, e.g. a removal carrying an older `lastSeen` than the local item.
  void emit(RemoteCollectionChange change) => _changes.add(change);

  void remoteRemove(String key) {
    final item = items.remove(key);
    if (item != null) _changes.add((item: item, removed: true));
  }

  Future<void> _ack() {
    if (failWrites) return Future.error(StateError('permission denied'));
    if (!holdAcks) return Future.value();
    final ack = Completer<void>();
    _heldAcks.add(ack);
    return ack.future;
  }

  void releaseAcks() {
    for (final ack in _heldAcks) {
      ack.complete();
    }
    _heldAcks.clear();
  }

  /// Like RTDB, a write rejected by the server is reverted, so it is neither stored nor recorded.
  @override
  Future<void> set(String key, Map<String, Object?> json) {
    if (failWrites) return Future.error(StateError('permission denied'));
    writes[key] = json;
    final item = CollectionItem.fromJson(json);
    items[key] = item;
    _changes.add((item: item, removed: false));
    return _ack();
  }

  @override
  Future<void> remove(String key) {
    if (failWrites) return Future.error(StateError('permission denied'));
    removed.add(key);
    remoteRemove(key);
    return _ack();
  }

  @override
  Future<void> close() async => closed = true;
}

/// Accounts enabled with fakes: per-profile sessions, Google sign-in, pairing functions and remote collections.
List<Override> authOverrides(
  FakeAuthBackend backend, {
  GoogleSignInService? google,
  Map<String, FakeRemoteCollection>? remotes,
}) => [
  accountsAvailableProvider.overrideWithValue(true),
  profileAuthFactoryProvider.overrideWithValue((profileId) async => backend.session(profileId)),
  googleSignInServiceProvider.overrideWithValue(google ?? FakeGoogleSignIn()),
  if (google == null) googleSignInAvailableProvider.overrideWithValue(false),
  pairingApiProvider.overrideWithValue(PairingApi(client: backend.client, domain: 'test.example')),
  remoteCollectionConnectorProvider.overrideWithValue(
    (profileId, uid) async => (remotes ?? {}).putIfAbsent(uid, FakeRemoteCollection.new),
  ),
];
