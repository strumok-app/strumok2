import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/utils/semver.dart';

void main() {
  test('parses with optional v prefix and missing parts', () {
    expect(SemVer.parse('v1.32.0'), const SemVer(1, 32, 0));
    expect(SemVer.parse('4'), const SemVer(4));
    expect(SemVer.parse('4.3'), const SemVer(4, 3));
    expect(SemVer.parse('V2.0.1-beta+5'), const SemVer(2, 0, 1));
  });

  test('rejects invalid input', () {
    expect(SemVer.tryParse(''), isNull);
    expect(SemVer.tryParse('latest'), isNull);
    expect(SemVer.tryParse('1.x'), isNull);
  });

  test('compares numerically', () {
    expect(SemVer.parse('1.10.0') > SemVer.parse('1.9.9'), isTrue);
    expect(SemVer.parse('2.0') > SemVer.parse('1.99.99'), isTrue);
    expect(SemVer.parse('1.0.0') < SemVer.parse('1.0.1'), isTrue);
    expect(SemVer.parse('v1.2') == SemVer.parse('1.2.0'), isTrue);
  });
}
