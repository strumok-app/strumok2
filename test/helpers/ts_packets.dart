import 'dart:typed_data';

import 'package:strumok/core/hls/ts_dejunker.dart';

const _p = TsDejunker.packetSize;

/// Spec-12 §12.6 packet generator.
Uint8List tsPackets(int count) {
  final out = Uint8List(count * _p);
  for (var i = 0; i < count; i++) {
    final start = i * _p;
    out.fillRange(start, start + _p, i + 1);
    out[start] = 0x47;
    out[start + 3] = 0x10 | (i % 16);
  }
  return out;
}

/// Junk that starts with a sync byte and has a second one a packet later: two aligned 0x47 are not enough.
Uint8List tsJunk(int length) {
  final out = Uint8List(length);
  if (length > 0) out[0] = 0x47;
  if (length > _p) out[_p] = 0x47;
  return out;
}

Uint8List concatBytes(List<List<int>> parts) => Uint8List.fromList([for (final p in parts) ...p]);
