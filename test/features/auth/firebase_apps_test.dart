import 'dart:io';

import 'package:firebase_dart/firebase_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/auth/data/firebase_apps.dart';

/// Real firebase_dart (no network needed): every profile gets its own app, isolate and storage directory.
void main() {
  test('apps of several profiles coexist in one process with separate storage', () async {
    final root = Directory.systemTemp.createTempSync('strumok_firebase');
    addTearDown(() => root.delete(recursive: true));
    final apps = ProfileFirebaseApps(
      root: root,
      options: const FirebaseOptions(
        apiKey: 'test-key',
        appId: '1:1:android:1',
        projectId: 'test-project',
        messagingSenderId: '1',
        databaseURL: 'https://test-project.firebaseio.com',
      ),
    );

    final a = await apps.app('a');
    final b = await apps.app('b');
    expect(identical(await apps.app('a'), a), isTrue);
    expect((a.name, b.name), ('profile-a', 'profile-b'));

    for (final app in [a, b]) {
      expect(await FirebaseAuth.instanceFor(app: app).userChanges().first, isNull);
    }
    expect(File('${root.path}/a/firebase_auth.hive').existsSync(), isTrue);
    expect(File('${root.path}/b/firebase_auth.hive').existsSync(), isTrue);

    await apps.delete('b');
    expect(Directory('${root.path}/b').existsSync(), isFalse);
    expect(Firebase.apps.map((app) => app.name), ['profile-a']);
  });
}
