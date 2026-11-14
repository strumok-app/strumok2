import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger('TsDejunker');

/// Strips the junk prefix (fake PNG/JPEG etc.) in front of a clear MPEG-TS segment (spec-12 §12.2).
///
/// One instance per segment: [feed] every chunk, then call [finish] at the end of the segment.
/// Shared by the HLS proxy and HLS downloads; never feed it fMP4 or encrypted bytes.
class TsDejunker {
  static const packetSize = 188;
  static const syncByte = 0x47;
  static const maxPendingBytes = 2 * 1024 * 1024;

  // Three sync bytes exactly one packet apart confirm the stream start.
  static const _confirmSpan = 2 * packetSize;

  Uint8List _pending = Uint8List(0);
  int _length = 0;
  int _scanFrom = 0;
  bool _syncFound = false;
  int _filteredBytes = 0;

  bool get syncFound => _syncFound;

  /// Junk bytes dropped in front of the first TS packet; valid once [syncFound].
  int get filteredBytes => _filteredBytes;

  /// Bytes to emit for [chunk], or null while still looking for the sync point.
  /// Throws [FormatException] when more than [maxPendingBytes] arrive without sync.
  Uint8List? feed(List<int> chunk) {
    if (_syncFound) return chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    _append(chunk);

    var i = _scanFrom;
    for (; i + _confirmSpan < _length; i++) {
      if (_pending[i] == syncByte && _pending[i + packetSize] == syncByte && _pending[i + _confirmSpan] == syncByte) {
        return _accept(i);
      }
    }
    _scanFrom = i;
    if (_length > maxPendingBytes) {
      throw FormatException('No MPEG-TS sync found in the first $_length bytes of segment');
    }
    return null;
  }

  /// Flushes a short segment (fewer than 3 packets) at the end of input; null when sync was already found.
  /// Throws [FormatException] when the segment has no MPEG-TS sync.
  Uint8List? finish() {
    if (_syncFound) return null;
    for (final packets in const [2, 1]) {
      final offset = _length - packets * packetSize;
      if (offset >= 0 && _packetsAlignedAt(offset)) return _accept(offset);
    }
    throw FormatException('No MPEG-TS sync found in segment ($_length bytes)');
  }

  bool _packetsAlignedAt(int offset) {
    for (var p = offset; p < _length; p += packetSize) {
      // adaptation_field_control == 0 is reserved, so a real packet header has one of these bits set.
      if (_pending[p] != syncByte || (_pending[p + 3] & 0x30) == 0) return false;
    }
    return true;
  }

  Uint8List _accept(int offset) {
    _syncFound = true;
    _filteredBytes = offset;
    if (offset > 0) _log.fine('Dropped $offset junk bytes before MPEG-TS sync');
    final out = Uint8List.sublistView(_pending, offset, _length);
    _pending = Uint8List(0);
    _length = 0;
    return out;
  }

  void _append(List<int> chunk) {
    final needed = _length + chunk.length;
    if (needed > _pending.length) {
      final grown = Uint8List(needed > _pending.length * 2 ? needed : _pending.length * 2);
      grown.setRange(0, _length, _pending);
      _pending = grown;
    }
    _pending.setRange(_length, needed, chunk);
    _length = needed;
  }
}
