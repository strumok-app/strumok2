import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/hls/ts_dejunker.dart';

import '../../helpers/ts_packets.dart';

const _p = TsDejunker.packetSize;

/// Feeds [chunks] and finishes; returns everything emitted.
Uint8List run(TsDejunker d, Iterable<List<int>> chunks) {
  final out = BytesBuilder();
  for (final c in chunks) {
    final emitted = d.feed(c);
    if (emitted != null) out.add(emitted);
  }
  final tail = d.finish();
  if (tail != null) out.add(tail);
  return out.takeBytes();
}

Iterable<List<int>> bytewise(Uint8List data) => [
  for (final b in data) [b],
];

void main() {
  test('clean 5-packet segment split at every boundary passes through unchanged', () {
    final data = tsPackets(5);
    for (var split = 1; split < data.length; split++) {
      final d = TsDejunker();
      final out = run(d, [data.sublist(0, split), data.sublist(split)]);
      expect(out, data, reason: 'split at $split');
      expect(d.filteredBytes, 0);
      expect(d.finish(), isNull, reason: 'nothing pending after sync');
    }
  });

  test('3 packets: sync confirmed on the 377th byte, then zero-copy passthrough', () {
    final data = tsPackets(3);
    final d = TsDejunker();
    expect(d.feed(data.sublist(0, 376)), isNull);
    expect(d.feed(data.sublist(376, 377)), data.sublist(0, 377));
    final rest = data.sublist(377);
    expect(d.feed(rest), same(rest));
    expect(d.finish(), isNull);
  });

  test('701-byte junk starting with 0x47 + 4 packets split at every boundary', () {
    final clean = tsPackets(4);
    final data = concatBytes([tsJunk(701), clean]);
    for (var split = 1; split < data.length; split++) {
      final d = TsDejunker();
      final out = run(d, [data.sublist(0, split), data.sublist(split)]);
      expect(out, clean, reason: 'split at $split');
      expect(d.filteredBytes, 701);
    }
  });

  for (final count in [1, 2]) {
    for (final junkLength in [0, 17, 701]) {
      test('$count packet(s) with $junkLength junk bytes fed byte by byte are flushed by finish()', () {
        final clean = tsPackets(count);
        final d = TsDejunker();
        final out = run(d, bytewise(concatBytes([tsJunk(junkLength), clean])));
        expect(out, clean);
        expect(d.filteredBytes, junkLength);
      });
    }
  }

  group('finish() throws without MPEG-TS sync', () {
    final cases = {
      'empty': Uint8List(0),
      '800 x 0x99': Uint8List(800)..fillRange(0, 800, 0x99),
      '187 bytes of a packet': tsPackets(1).sublist(0, 187),
      'only the sync byte': Uint8List(_p)..[0] = 0x47,
    };
    cases.forEach((name, data) {
      test(name, () {
        final d = TsDejunker();
        expect(d.feed(data), isNull);
        expect(d.finish, throwsFormatException);
      });
    });
  });

  test('fails the segment when more than 2 MiB arrive without sync', () {
    final d = TsDejunker();
    final chunk = Uint8List(64 * 1024);
    expect(() {
      for (var i = 0; i < 40; i++) {
        d.feed(chunk);
      }
    }, throwsFormatException);
  });
}
