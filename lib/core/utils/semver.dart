/// Minimal semantic version: `major.minor.patch`, optional leading `v`, missing parts are 0.
/// Pre-release/build suffixes are ignored.
final class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;

  const SemVer(this.major, [this.minor = 0, this.patch = 0]);

  static final _pattern = RegExp(r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-+].*)?$');

  static SemVer? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    return SemVer(
      int.parse(match.group(1)!),
      int.tryParse(match.group(2) ?? '') ?? 0,
      int.tryParse(match.group(3) ?? '') ?? 0,
    );
  }

  static SemVer parse(String input) => tryParse(input) ?? (throw FormatException('Invalid version', input));

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
