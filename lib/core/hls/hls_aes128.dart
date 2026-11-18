import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

/// HLS `METHOD=AES-128` segments: AES-128-CBC with PKCS#7 padding (RFC 8216 §5.2). Used by HLS downloads, which
/// decrypt before dejunking (spec-12 §12.3); the proxy passes encrypted segments through.
abstract final class HlsAes128 {
  static const keyLength = 16;

  /// Throws [ArgumentError] for a key or IV that is not 16 bytes, and [FormatException] for data that is not a
  /// non-empty whole number of blocks with valid padding (a broken or truncated segment).
  static Uint8List decrypt(Uint8List data, {required Uint8List key, required Uint8List iv}) {
    if (key.length != keyLength) throw ArgumentError.value(key.length, 'key', 'AES-128 key must be 16 bytes');
    if (iv.length != keyLength) throw ArgumentError.value(iv.length, 'iv', 'AES-128 IV must be 16 bytes');
    if (data.isEmpty || data.length % keyLength != 0) {
      throw FormatException('AES-128 data is not a whole number of blocks (${data.length} bytes)');
    }
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        false,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    try {
      return cipher.process(data);
    } on ArgumentError catch (e) {
      throw FormatException('Invalid AES-128 padding: ${e.message}');
    }
  }

  /// For tests and fixtures: the inverse of [decrypt].
  static Uint8List encrypt(Uint8List data, {required Uint8List key, required Uint8List iv}) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return cipher.process(data);
  }

  /// IV when `EXT-X-KEY` has no `IV` attribute: the segment's media sequence number as a 16-byte big-endian
  /// value (RFC 8216 §5.2; the legacy app used a zero IV).
  static Uint8List sequenceIv(int sequence) {
    final iv = Uint8List(keyLength);
    var value = sequence;
    for (var i = keyLength - 1; i >= 0 && value > 0; i--) {
      iv[i] = value & 0xff;
      value >>= 8;
    }
    return iv;
  }
}
