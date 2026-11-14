import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/player/domain/player_session.dart';

import '../../helpers/fake_player.dart';

void main() {
  group('startPosition', () {
    test('fromRemembered resumes the stored position', () {
      expect(
        startPosition(StartFrom.fromRemembered, remembered: const MediaItemPosition(position: 300, length: 3000)),
        300,
      );
      expect(startPosition(StartFrom.fromRemembered), 0);
    });

    test('steps back 60 s near the end of a known length', () {
      expect(
        startPosition(StartFrom.fromRemembered, remembered: const MediaItemPosition(position: 2970, length: 3000)),
        2910,
      );
      expect(startPosition(StartFrom.fromRemembered, remembered: const MediaItemPosition(position: 2970)), 2970);
    });

    test('fromBeginning and fromFixedPosition; never negative', () {
      const remembered = MediaItemPosition(position: 500, length: 3000);
      expect(startPosition(StartFrom.fromBeginning, remembered: remembered), 0);
      expect(startPosition(StartFrom.fromFixedPosition, remembered: remembered, fixedSeconds: 90), 90);
      expect(startPosition(StartFrom.fromBeginning, remembered: const MediaItemPosition(position: 0, length: 30)), 0);
    });
  });

  test('chooseSource picks currentSourceName, else the first source', () {
    final sources = [FakeVideoSource('A'), FakeVideoSource('B')];
    expect(chooseSource(sources, 'B'), 1);
    expect(chooseSource(sources, 'gone'), 0);
    expect(chooseSource(sources, null), 0);
  });
}
