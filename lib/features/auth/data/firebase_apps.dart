import 'dart:async';
import 'dart:convert';
import 'dart:io';

// The public `FirebaseDart.setup` supports one storage directory per process; per-profile isolation needs the
// implementation classes directly (firebase_dart is pinned, see pubspec.yaml).
// ignore_for_file: implementation_imports
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firebase_dart/implementation/pure_dart.dart';
import 'package:firebase_dart/src/auth/sms_retriever.dart' show DummySmsRetriever;
import 'package:firebase_dart/src/auth/utils.dart' show initPlatform;
import 'package:firebase_dart/src/implementation.dart';
import 'package:firebase_dart/src/implementation/isolate.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _log = Logger('FirebaseApps');

/// Parses the `FIREBASE` define (FirebaseOptions map, spec-04 §4.1); null when absent or invalid.
FirebaseOptions? parseFirebaseOptions(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    return FirebaseOptions.fromMap((jsonDecode(raw) as Map).cast<String, dynamic>());
  } catch (e) {
    // Never log the value itself (spec-10).
    _log.severe('FIREBASE define is not a valid FirebaseOptions JSON map');
    return null;
  }
}

/// One Firebase app per profile, created lazily (spec-05 §5.2).
///
/// firebase_dart keys the persisted user by `options.appId` and the database cache by the database host, so two
/// apps sharing one storage directory would also share the signed-in user. Each profile therefore runs its own
/// isolated implementation (worker isolate with its own Hive storage under `<appSupport>/firebase/<profileId>`).
/// `FirebaseDart.setup` may only run once per process, so a single [_ProfileRoutingImplementation] is installed
/// instead and forwards every call to the implementation registered for the app's name.
class ProfileFirebaseApps {
  final FirebaseOptions options;
  final Directory root;

  final _apps = <String, Future<FirebaseApp>>{};

  ProfileFirebaseApps({required this.options, required this.root});

  static String appName(String profileId) => 'profile-$profileId';

  Directory storageFor(String profileId) => Directory(p.join(root.path, profileId));

  Future<FirebaseApp> app(String profileId) {
    final app = _apps[profileId] ??= _create(profileId);
    // A failed setup is retried on the next call.
    return app.catchError((Object e) {
      _apps.remove(profileId);
      throw e;
    });
  }

  Future<FirebaseApp> _create(String profileId) async {
    final storage = storageFor(profileId);
    await storage.create(recursive: true);
    final name = appName(profileId);
    // A previous app of a deleted profile may still be registered under this name.
    if (Firebase.apps.any((a) => a.name == name)) return Firebase.app(name);
    _ProfileRoutingImplementation.instance.register(name, storage.path);
    final app = await Firebase.initializeApp(name: name, options: options);
    _log.fine('Firebase app ready for profile $profileId');
    return app;
  }

  /// Closes the profile's app and removes its persisted session and database cache.
  Future<void> delete(String profileId) async {
    final app = _apps.remove(profileId);
    if (app != null) {
      try {
        await (await app).delete();
      } catch (e) {
        _log.warning('Could not delete Firebase app of $profileId', e);
      }
    }
    final storage = storageFor(profileId);
    try {
      if (storage.existsSync()) await storage.delete(recursive: true);
    } catch (e) {
      _log.warning('Could not delete ${storage.path}', e);
    }
  }
}

/// Process-wide firebase_dart implementation routing each app to its own isolated worker (see [ProfileFirebaseApps]).
class _ProfileRoutingImplementation extends FirebaseImplementation {
  static final instance = _ProfileRoutingImplementation._();

  final _byApp = <String, IsolateFirebaseImplementation>{};

  _ProfileRoutingImplementation._() {
    // What `FirebaseDart.setup` does once per process, minus installing a single shared implementation.
    FirebaseDart.baseUrl = Uri.base;
    initPlatform(_platform);
    FirebaseImplementation.install(this);
  }

  static final _platform = Platform.linux(isOnline: true);

  void register(String appName, String storagePath) => _byApp[appName] ??= IsolateFirebaseImplementation(
    storagePath: storagePath,
    platform: _platform,
    launchUrl: (uri, {popup = false}) => throw UnsupportedError('Redirect sign-in is not used'),
    authHandler: const AuthHandler(),
    applicationVerifier: const RecaptchaApplicationVerifier(),
    smsRetriever: DummySmsRetriever(),
  );

  IsolateFirebaseImplementation _for(String appName) =>
      _byApp[appName] ?? (throw StateError('No Firebase implementation registered for $appName'));

  @override
  Future<FirebaseApp> createApp(String name, FirebaseOptions options) => _for(name).createApp(name, options);

  @override
  FirebaseAuth createAuth(covariant IsolateFirebaseApp app) => _for(app.name).createAuth(app);

  @override
  FirebaseDatabase createDatabase(covariant IsolateFirebaseApp app, {String? databaseURL}) =>
      _for(app.name).createDatabase(app, databaseURL: databaseURL);

  @override
  FirebaseStorage createStorage(covariant IsolateFirebaseApp app, {String? storageBucket}) =>
      _for(app.name).createStorage(app, storageBucket: storageBucket);

  @override
  Future<void> updateDatabaseConfiguration({Duration? keepQueriesSyncedDuration}) => Future.wait([
    for (final implementation in _byApp.values)
      implementation.updateDatabaseConfiguration(keepQueriesSyncedDuration: keepQueriesSyncedDuration),
  ]);
}
