import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/domain/collection_query.dart';
import 'package:strumok/features/collection/domain/merge.dart';
import 'package:strumok/features/collection/domain/progress.dart';

CollectionItem item({
  String id = 'x',
  String title = 'Title',
  int lastSeen = 100,
  CollectionStatus status = CollectionStatus.latter,
  CollectionPriority priority = CollectionPriority.normal,
  Map<int, MediaItemPosition> positions = const {},
  MediaType mediaType = MediaType.video,
}) => CollectionItem(
  id: id,
  supplier: 's',
  title: title,
  image: '',
  lastSeen: lastSeen,
  status: status,
  priority: priority,
  positions: positions,
  mediaType: mediaType,
);

void main() {
  group('merge matrix (spec-03 §3.4)', () {
    const p = MediaItemPosition.new;

    test('upsert applies only when remote is strictly newer; positions merged, remote wins per key', () {
      final local = item(lastSeen: 100, positions: {0: p(position: 10), 1: p(position: 20)});
      final remote = item(lastSeen: 200, title: 'Remote', positions: {1: p(position: 99), 2: p(position: 30)});

      final merged = mergeRemoteUpsert(local, remote)!;
      expect(merged.title, 'Remote');
      expect(merged.positions, {0: p(position: 10), 1: p(position: 99), 2: p(position: 30)});

      expect(mergeRemoteUpsert(local, item(lastSeen: 100)), isNull, reason: 'equal');
      expect(mergeRemoteUpsert(local, item(lastSeen: 50)), isNull, reason: 'older');
      expect(mergeRemoteUpsert(null, remote), same(remote), reason: 'new item');
    });

    test('remove applies when remote is at least as new', () {
      final local = item(lastSeen: 100);
      expect(shouldApplyRemoteRemove(local, 200), isTrue);
      expect(shouldApplyRemoteRemove(local, 100), isTrue);
      expect(shouldApplyRemoteRemove(local, 99), isFalse);
      expect(shouldApplyRemoteRemove(null, 100), isFalse);
    });
  });

  group('progress rules (spec-03 §3.3)', () {
    test('video position persists past 10 s and when moved more than 10 s; sets inProgress', () {
      final base = item(status: CollectionStatus.complete);
      expect(updateVideoProgress(base, itemIndex: 0, position: 10), isNull);

      final first = updateVideoProgress(base, itemIndex: 0, position: 11)!;
      expect(first.positions[0]!.position, 11);
      expect(first.status, CollectionStatus.inProgress, reason: 'legacy: regardless of previous status');

      expect(updateVideoProgress(first, itemIndex: 0, position: 21), isNull);
      expect(updateVideoProgress(first, itemIndex: 0, position: 22)!.positions[0]!.position, 22);
    });

    test('known length is stored and clamps the position', () {
      final withLength = updateVideoProgress(item(), itemIndex: 1, position: 5, length: 1400)!;
      expect(withLength.positions[1], const MediaItemPosition(position: 0, length: 1400));
      expect(withLength.status, CollectionStatus.inProgress);

      final end = updateVideoProgress(withLength, itemIndex: 1, position: 2000)!;
      expect(end.positions[1], const MediaItemPosition(position: 1399, length: 1400));
    });

    test('manga persists on page change', () {
      final base = item(mediaType: MediaType.manga);
      final page3 = updateMangaProgress(base, itemIndex: 0, page: 3, pageCount: 20)!;
      expect(page3.positions[0], const MediaItemPosition(position: 3, length: 20));
      expect(updateMangaProgress(page3, itemIndex: 0, page: 3), isNull);
      expect(updateMangaProgress(page3, itemIndex: 0, page: 4)!.positions[0]!.length, 20);
    });

    test('priority requires the item to be in the collection', () {
      expect(updatePriority(item(status: CollectionStatus.none), CollectionPriority.high), isNull);
      expect(updatePriority(item(), CollectionPriority.high)!.priority, CollectionPriority.high);
      expect(updatePriority(item(), CollectionPriority.normal), isNull);
    });
  });

  group('query', () {
    test('tokens are lowercase, Cyrillic aware', () {
      expect(searchTokens('Тіні забутих Предків: Part-2'), ['тіні', 'забутих', 'предків', 'part', '2']);
      expect(searchTokens('Ґрунт і Їжак'), ['ґрунт', 'і', 'їжак']);
    });

    test('word-prefix match, OR of words, case-insensitive', () {
      final tokens = searchTokens('Тіні забутих предків');
      expect(matchesQuery(tokens, 'ЗАБ'), isTrue);
      expect(matchesQuery(tokens, 'xyz пред'), isTrue);
      expect(matchesQuery(tokens, 'утих'), isFalse, reason: 'prefix only');
      expect(matchesQuery(tokens, ''), isTrue);
    });

    test('groups in status order, sorted by priority then lastSeen; filters apply', () {
      final items = [
        item(id: 'a', status: CollectionStatus.complete),
        item(id: 'b', status: CollectionStatus.inProgress, lastSeen: 1),
        item(id: 'c', status: CollectionStatus.inProgress, lastSeen: 2),
        item(id: 'd', status: CollectionStatus.inProgress, priority: CollectionPriority.high),
        item(id: 'e', status: CollectionStatus.latter, mediaType: MediaType.manga),
        item(id: 'f', status: CollectionStatus.none),
      ];
      final groups = groupCollection(items, const CollectionFilter());
      expect(groups.map((g) => g.$1), [
        CollectionStatus.inProgress,
        CollectionStatus.latter,
        CollectionStatus.complete,
      ]);
      expect(groups.first.$2.map((i) => i.id), ['d', 'c', 'b']);

      final manga = groupCollection(items, const CollectionFilter(mediaTypes: {MediaType.manga}));
      expect(manga.single.$2.single.id, 'e');
    });

    test('continue row: in progress, else watch later', () {
      expect(continueItems([item(id: 'l'), item(id: 'p', status: CollectionStatus.inProgress)]).map((i) => i.id), [
        'p',
      ]);
      expect(continueItems([item(id: 'l'), item(id: 'c', status: CollectionStatus.complete)]).map((i) => i.id), ['l']);
    });
  });
}
