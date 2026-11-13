import 'dart:math';

final class Profile {
  final String id;
  final String name;

  /// Avatar color (ARGB).
  final int colorSeed;

  /// Set when linked to a Google account (M4).
  final String? firebaseUid;
  final String? accountName;
  final String? accountPhotoUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    required this.colorSeed,
    required this.createdAt,
    this.firebaseUid,
    this.accountName,
    this.accountPhotoUrl,
  });

  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    colorSeed: (json['colorSeed'] as num).toInt(),
    createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt()),
    firebaseUid: json['firebaseUid'] as String?,
    accountName: json['accountName'] as String?,
    accountPhotoUrl: json['accountPhotoUrl'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorSeed': colorSeed,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'firebaseUid': firebaseUid,
    'accountName': accountName,
    'accountPhotoUrl': accountPhotoUrl,
  };

  Profile copyWith({String? name, int? colorSeed}) => Profile(
    id: id,
    name: name ?? this.name,
    colorSeed: colorSeed ?? this.colorSeed,
    createdAt: createdAt,
    firebaseUid: firebaseUid,
    accountName: accountName,
    accountPhotoUrl: accountPhotoUrl,
  );

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}

/// Avatar palette (ARGB).
const profileColors = [0xFF6B7A2F, 0xFFB0213A, 0xFF1E6FA8, 0xFF7B4FA0, 0xFFC26A00, 0xFF2E8B6E, 0xFF8A5A44, 0xFF5C6B7A];

/// Random UUID v4.
String newProfileId([Random? random]) {
  final rnd = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
