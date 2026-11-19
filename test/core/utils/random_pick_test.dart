import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/utils/random_pick.dart';

void main() {
  test('never picks excluded items; null when all are excluded', () {
    final random = Random(1);
    for (var i = 0; i < 50; i++) {
      expect(pickRandomIndex(['a', 'b', 'c'], random, exclude: {0, 2}), 1);
    }
    expect(pickRandomIndex(['a', 'b'], random, exclude: {0, 1}), isNull);
    expect(pickRandomIndex(const <String>[], random), isNull);
  });

  test('weights make items proportionally more likely; zero weight is never picked', () {
    final random = Random(7);
    final counts = [0, 0, 0];
    final weights = {'low': 1.0, 'high': 4.0, 'none': 0.0};
    for (var i = 0; i < 5000; i++) {
      counts[pickRandomIndex(['low', 'high', 'none'], random, weight: (s) => weights[s]!)!]++;
    }
    expect(counts[2], 0);
    expect(counts[1] / counts[0], closeTo(4, 0.5));
  });

  test('all-zero weights fall back to a uniform pick', () {
    final picked = pickRandomIndex(['a', 'b'], Random(3), weight: (_) => 0);
    expect(picked, isIn([0, 1]));
  });
}
