import 'dart:convert';
import 'dart:typed_data';

/// Subtitle file bytes to text: BOM-aware (UTF-8, UTF-16 LE/BE), UTF-8, else Windows-1251 — the usual encoding of
/// Ukrainian/Russian SRT files that are not UTF-8.
String decodeSubtitleBytes(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) return _utf16(bytes.sublist(2), Endian.little);
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) return _utf16(bytes.sublist(2), Endian.big);
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return String.fromCharCodes(bytes.map((b) => b < 0x80 ? b : _cp1251[b - 0x80]));
  }
}

String _utf16(Uint8List bytes, Endian endian) {
  final data = ByteData.sublistView(bytes);
  return String.fromCharCodes([for (var i = 0; i + 1 < bytes.length; i += 2) data.getUint16(i, endian)]);
}

// Windows-1251, bytes 0x80..0xFF; unassigned 0x98 maps to U+FFFD.
final _cp1251 = [
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, 0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, //
  0x040B, 0x040F, 0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0xFFFD, 0x2122, 0x0459, 0x203A,
  0x045A, 0x045C, 0x045B, 0x045F, 0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7, 0x0401, 0x00A9,
  0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407, 0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
  // 0xC0..0xFF: А..я
  for (var c = 0x0410; c <= 0x044F; c++) c,
];
