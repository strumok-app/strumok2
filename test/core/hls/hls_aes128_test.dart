import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/hls/hls_aes128.dart';

void main() {
  final key = Uint8List.fromList(List.generate(16, (i) => i));

  test('decrypts what was encrypted, with PKCS#7 padding removed', () {
    final iv = Uint8List(16)..[15] = 9;
    for (final length in [1, 15, 16, 17, 188 * 3]) {
      final data = Uint8List.fromList(List.generate(length, (i) => i % 251));
      final encrypted = HlsAes128.encrypt(data, key: key, iv: iv);
      expect(encrypted.length % 16, 0);
      expect(HlsAes128.decrypt(encrypted, key: key, iv: iv), data);
    }
  });

  test('known vector: AES-128-CBC (NIST SP 800-38A F.2.1, first block)', () {
    Uint8List hex(String s) =>
        Uint8List.fromList([for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);
    final nistKey = hex('2b7e151628aed2a6abf7158809cf4f3c');
    final iv = hex('000102030405060708090a0b0c0d0e0f');
    final plain = hex('6bc1bee22e409f96e93d7e117393172a');
    final encrypted = HlsAes128.encrypt(plain, key: nistKey, iv: iv);
    expect(encrypted.sublist(0, 16), hex('7649abac8119b246cee98e9b12e9197d'));
  });

  test('media-sequence IV is 16-byte big-endian', () {
    expect(HlsAes128.sequenceIv(0), Uint8List(16));
    expect(HlsAes128.sequenceIv(1).last, 1);
    expect(HlsAes128.sequenceIv(0x01020304).sublist(12), [1, 2, 3, 4]);
    expect(HlsAes128.sequenceIv(0x01020304).sublist(0, 12), everyElement(0));
  });

  test('broken data is a FormatException (retried as a bad segment)', () {
    final iv = Uint8List(16);
    expect(() => HlsAes128.decrypt(Uint8List(0), key: key, iv: iv), throwsFormatException);
    expect(() => HlsAes128.decrypt(Uint8List(20), key: key, iv: iv), throwsFormatException);
    // Decrypting with a wrong key garbles the padding.
    final encrypted = HlsAes128.encrypt(Uint8List(40), key: key, iv: iv);
    expect(() => HlsAes128.decrypt(encrypted, key: Uint8List(16)..[0] = 1, iv: iv), throwsFormatException);
  });

  test('rejects keys and IVs of the wrong size', () {
    expect(() => HlsAes128.decrypt(Uint8List(16), key: Uint8List(8), iv: Uint8List(16)), throwsArgumentError);
    expect(() => HlsAes128.decrypt(Uint8List(16), key: key, iv: Uint8List(4)), throwsArgumentError);
  });
}
