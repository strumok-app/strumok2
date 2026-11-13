import 'dart:convert';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';

Object? fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

const legacyKeys = {
  'id',
  'supplier',
  'title',
  'image',
  'mediaType',
  'currentItem',
  'currentSourceName',
  'currentSubtitleName',
  'positions',
  'status',
  'priority',
  'lastSeen',
};

void main() {
  group('itemKey (spec-03 §3.1)', () {
    test('no separator, "/" → "|", "." removed', () {
      expect(collectionItemKey('uakino', 'some/film/123-title.html'), 'uakinosome|film|123-titlehtml');
      expect(collectionItemKey('s', 'a.b.c'), 'sabc');
      expect(collectionItemKey('s', '/'), 's|');
    });

    test('unicode is kept', () {
      expect(collectionItemKey('uaserials', 'серіал/тіні.забутих'), 'uaserialsсеріал|тінізабутих');
    });
  });

  group('legacy JSON', () {
    final snapshot = (fixture('legacy_collection_item.json')! as Map).cast<String, Object?>();

    test('every item parses; keys match the RTDB keys; every status value is known', () {
      final items = {for (final e in snapshot.entries) e.key: CollectionItem.fromJson(e.value! as Map)};
      for (final e in items.entries) {
        expect(e.value.key, e.key);
      }
      expect(items.values.map((i) => i.status).toSet(), CollectionStatus.values.toSet());

      final film = items['uakinosome|film|123-titlehtml']!;
      expect(film.mediaType, MediaType.video);
      expect(film.currentItem, 3);
      expect(film.currentSourceName, 'Server 1 (UA)');
      expect(film.positions[3], const MediaItemPosition(position: 412, length: 1400));
      expect(film.priority, CollectionPriority.high);
      expect(film.lastSeen, 1731222222000);
      expect(items['mangadexabc']!.mediaType, MediaType.manga);
    });

    test('round-trip writes exactly the legacy key set and values', () {
      for (final raw in snapshot.values) {
        final json = CollectionItem.fromJson(raw! as Map).toJson();
        expect(json.keys.toSet(), legacyKeys);
        expect(jsonDecode(jsonEncode(json)), raw);
      }
    });
  });

  test('positions as array with holes, numbers as doubles, unknown fields and missing defaults', () {
    final item = CollectionItem.fromJson(fixture('legacy_collection_item_positions_array.json')! as Map);
    expect(item.positions.keys, [0, 2]);
    expect(item.positions[0], const MediaItemPosition(position: 1300, length: 1420));
    expect(item.currentItem, 2);
    expect(item.lastSeen, 1731222222000);
    expect(item.mediaType, MediaType.video, reason: 'missing → video');
    expect(item.priority, CollectionPriority.normal, reason: 'missing → 1');
    expect(item.toJson().keys.toSet(), legacyKeys);
    expect(item.toJson()['positions'], {
      '0': {'position': 1300, 'length': 1420},
      '2': {'position': 61, 'length': 1420},
    });
  });

  test('missing optional fields', () {
    final item = CollectionItem.fromJson({'id': 'x', 'supplier': 's', 'title': 't', 'image': 'i'});
    expect(item.status, CollectionStatus.none);
    expect(item.positions, isEmpty);
    expect(item.lastSeen, 0);
  });
}
