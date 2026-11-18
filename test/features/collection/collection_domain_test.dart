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
    test('video position persists past 10 s and when moved more than 10 s', () {
      final base = item(status: CollectionStatus.complete);
      expect(updateVideoProgress(base, itemIndex: 0, position: 10), isNull);

      final first = updateVideoProgress(base, itemIndex: 0, position: 11)!;
      expect(first.positions[0]!.position, 11);
      expect(first.status, CollectionStatus.complete, reason: 'an existing status is kept');

      expect(updateVideoProgress(first, itemIndex: 0, position: 21), isNull);
      expect(updateVideoProgress(first, itemIndex: 0, position: 22)!.positions[0]!.position, 22);
    });

    test('progress adds a title that is not in the collection as inProgress', () {
      final video = item(status: CollectionStatus.none);
      expect(updateVideoProgress(video, itemIndex: 0, position: 11)!.status, CollectionStatus.inProgress);
      expect(updateVideoProgress(video, itemIndex: 0, position: 0, length: 1400)!.status, CollectionStatus.inProgress);

      final manga = item(status: CollectionStatus.none, mediaType: MediaType.manga);
      expect(updateMangaProgress(manga, itemIndex: 0, page: 0)!.status, CollectionStatus.inProgress);
    });

    test('progress keeps every existing status', () {
      for (final status in CollectionStatus.values.where((s) => s != CollectionStatus.none)) {
        expect(updateVideoProgress(item(status: status), itemIndex: 0, position: 11)!.status, status);
        expect(
          updateMangaProgress(item(status: status, mediaType: MediaType.manga), itemIndex: 0, page: 1)!.status,
          status,
        );
      }
    });

    test('video saves backward movement only when it exceeds 10 s', () {
      final base = item(positions: {0: const MediaItemPosition(position: 100, length: 1000)});
      expect(updateVideoProgress(base, itemIndex: 0, position: 90), isNull);
      expect(
        updateVideoProgress(base, itemIndex: 0, position: 89)!.positions[0],
        const MediaItemPosition(position: 89, length: 1000),
      );
    });

    test('known length is stored without saving positions in the final 60 s', () {
      final withLength = updateVideoProgress(item(), itemIndex: 1, position: 5, length: 1400)!;
      expect(withLength.positions[1], const MediaItemPosition(position: 0, length: 1400));
      expect(withLength.status, CollectionStatus.latter);

      expect(updateVideoProgress(withLength, itemIndex: 1, position: 2000), isNull);
    });

    test('video position persists with 61 s remaining but not 60 s or less', () {
      final base = item(positions: {0: const MediaItemPosition(position: 1200, length: 1400)});
      expect(updateVideoProgress(base, itemIndex: 0, position: 1339)!.positions[0]!.position, 1339);
      for (final position in [1340, 1341, 1400, 2000]) {
        expect(updateVideoProgress(base, itemIndex: 0, position: position), isNull);
        expect(updateVideoProgress(base, itemIndex: 0, position: position, length: 1400), isNull);
      }
    });

    test('learning or changing length in the tail preserves the stored position', () {
      final base = item(positions: {0: const MediaItemPosition(position: 1200)});
      final updated = updateVideoProgress(base, itemIndex: 0, position: 1350, length: 1400)!;
      expect(updated.positions[0], const MediaItemPosition(position: 1200, length: 1400));
      expect(updated.status, CollectionStatus.latter);
      expect(
        updateVideoProgress(updated, itemIndex: 0, position: 1380, length: 1420)!.positions[0],
        const MediaItemPosition(position: 1200, length: 1420),
      );
      expect(
        updateVideoProgress(item(), itemIndex: 0, position: 1350, length: 1400)!.positions[0],
        const MediaItemPosition(position: 0, length: 1400),
      );
    });

    test('the saving tail is a fixed 60 s even for short videos', () {
      final base = item(positions: {0: const MediaItemPosition(position: 0, length: 120)});
      expect(updateVideoProgress(base, itemIndex: 0, position: 59)!.positions[0]!.position, 59);
      expect(updateVideoProgress(base, itemIndex: 0, position: 60), isNull);
      expect(
        updateVideoProgress(item(), itemIndex: 0, position: 20, length: 60)!.positions[0],
        const MediaItemPosition(position: 0, length: 60),
      );
    });

    test('manga persists on page change', () {
      final base = item(mediaType: MediaType.manga);
      final page3 = updateMangaProgress(base, itemIndex: 0, page: 3, pageCount: 20)!;
      expect(page3.positions[0], const MediaItemPosition(position: 3, length: 20));
      expect(updateMangaProgress(page3, itemIndex: 0, page: 3), isNull);
      expect(updateMangaProgress(page3, itemIndex: 0, page: 4)!.positions[0]!.length, 20);
    });

    test('manga persists page count changes even when the page stays the same', () {
      final base = item(
        mediaType: MediaType.manga,
        status: CollectionStatus.complete,
        positions: {
          0: const MediaItemPosition(position: 3, length: 20),
          1: const MediaItemPosition(position: 5, length: 12),
        },
      );
      expect(updateMangaProgress(base, itemIndex: 0, page: 3, pageCount: 20), isNull);
      expect(updateMangaProgress(base, itemIndex: 0, page: 3), isNull);

      final updated = updateMangaProgress(base, itemIndex: 0, page: 3, pageCount: 21)!;
      expect(updated.positions[0], const MediaItemPosition(position: 3, length: 21));
      expect(updated.positions[1], base.positions[1]);
      expect(updated.status, CollectionStatus.complete);
    });

    test('manga creates first-page progress and preserves length for non-positive page counts', () {
      final firstPage = updateMangaProgress(item(mediaType: MediaType.manga), itemIndex: 0, page: 0)!;
      expect(firstPage.positions[0], const MediaItemPosition(position: 0, length: 0));

      final base = item(mediaType: MediaType.manga, positions: {0: const MediaItemPosition(position: 3, length: 20)});
      expect(
        updateMangaProgress(base, itemIndex: 0, page: 4, pageCount: 0)!.positions[0],
        const MediaItemPosition(position: 4, length: 20),
      );
      expect(
        updateMangaProgress(base, itemIndex: 0, page: 3, pageCount: -1)!.positions[0],
        const MediaItemPosition(position: 3, length: 20),
      );
    });

    test('priority requires the item to be in the collection', () {
      expect(updatePriority(item(status: CollectionStatus.none), CollectionPriority.high), isNull);
      expect(updatePriority(item(), CollectionPriority.high)!.priority, CollectionPriority.high);
      expect(updatePriority(item(), CollectionPriority.normal), isNull);
    });
  });

  group('item completion and progress display', () {
    const video = MediaType.video;
    const manga = MediaType.manga;

    test('video is watched within the last 60 s (10% for short videos)', () {
      expect(isMediaItemCompleted(video, const MediaItemPosition(position: 2639, length: 2700)), isFalse);
      expect(isMediaItemCompleted(video, const MediaItemPosition(position: 2640, length: 2700)), isTrue);
      expect(isMediaItemCompleted(video, const MediaItemPosition(position: 60, length: 120)), isFalse);
      expect(isMediaItemCompleted(video, const MediaItemPosition(position: 108, length: 120)), isTrue);
      expect(isMediaItemCompleted(video, const MediaItemPosition(position: 5000)), isFalse);
    });

    test('manga is read on the last page', () {
      expect(isMediaItemCompleted(manga, const MediaItemPosition(position: 18, length: 20)), isFalse);
      expect(isMediaItemCompleted(manga, const MediaItemPosition(position: 19, length: 20)), isTrue);
      expect(isMediaItemCompleted(manga, const MediaItemPosition(position: 3)), isFalse);
    });

    test('progress fraction', () {
      expect(mediaItemProgress(video, const MediaItemPosition(position: 600, length: 2400)), 0.25);
      expect(mediaItemProgress(video, const MediaItemPosition(position: 2390, length: 2400)), 1);
      expect(mediaItemProgress(video, const MediaItemPosition(position: 600)), isNull);
      expect(mediaItemProgress(manga, const MediaItemPosition(position: 4, length: 20)), 0.25);
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
