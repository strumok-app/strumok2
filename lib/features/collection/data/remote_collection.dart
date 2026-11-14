import 'dart:async';

import 'package:firebase_dart/firebase_dart.dart';
import 'package:logging/logging.dart';

import '../domain/collection_item.dart';

final _log = Logger('RemoteCollection');

/// A change at `/collection/{uid}`: upsert for added/changed children, removal with the last known item.
typedef RemoteCollectionChange = ({CollectionItem item, bool removed});

/// The user's collection in Firebase Realtime Database: `/collection/{uid}/{itemKey}` (spec-03 §3.1).
abstract interface class RemoteCollection {
  /// Current items by key (from the synced cache when available).
  Future<Map<String, CollectionItem>> fetchAll();

  /// Child added/changed/removed events, starting with every existing child.
  Stream<RemoteCollectionChange> changes();

  /// Completes when the server confirmed the write (writes are queued while offline).
  Future<void> set(String key, Map<String, Object?> json);

  Future<void> remove(String key);

  Future<void> close();
}

/// Tolerant parse of a remote item; malformed children are skipped (spec-03 §3.2).
CollectionItem? parseRemoteItem(Object? value) {
  if (value is! Map) return null;
  try {
    return CollectionItem.fromJson(value);
  } catch (e) {
    _log.warning('Skipping malformed collection item', e);
    return null;
  }
}

class FirebaseRemoteCollection implements RemoteCollection {
  final DatabaseReference _ref;
  final _subscriptions = <StreamSubscription<Event>>[];

  FirebaseRemoteCollection._(this._ref);

  /// Enables RTDB persistence (before any other use of the app's database) and keeps the collection synced.
  static Future<FirebaseRemoteCollection> connect(FirebaseApp app, String uid) async {
    final database = FirebaseDatabase(app: app);
    await database.setPersistenceEnabled(true);
    final ref = database.reference().child('collection').child(uid);
    await ref.keepSynced(true);
    return FirebaseRemoteCollection._(ref);
  }

  @override
  Future<Map<String, CollectionItem>> fetchAll() async {
    final value = (await _ref.once()).value;
    if (value is! Map) return const {};
    final items = value.values.map(parseRemoteItem).nonNulls;
    return {for (final item in items) item.key: item};
  }

  @override
  Stream<RemoteCollectionChange> changes() {
    late final StreamController<RemoteCollectionChange> controller;
    void listen(Stream<Event> events, {required bool removed}) {
      _subscriptions.add(
        events.listen((event) {
          if (parseRemoteItem(event.snapshot.value) case final item?) controller.add((item: item, removed: removed));
        }, onError: controller.addError),
      );
    }

    controller = StreamController(
      onListen: () {
        listen(_ref.onChildAdded, removed: false);
        listen(_ref.onChildChanged, removed: false);
        listen(_ref.onChildRemoved, removed: true);
      },
      onCancel: _cancel,
    );
    return controller.stream;
  }

  @override
  Future<void> set(String key, Map<String, Object?> json) => _ref.child(key).set(json);

  @override
  Future<void> remove(String key) => _ref.child(key).remove();

  Future<void> _cancel() async {
    final subscriptions = [..._subscriptions];
    _subscriptions.clear();
    for (final s in subscriptions) {
      await s.cancel();
    }
  }

  @override
  Future<void> close() => _cancel();
}
