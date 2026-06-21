import 'package:flutter_test/flutter_test.dart';

import 'package:assignfilament/src/core/weigh_math.dart';

void main() {
  group('WeighMath.remainingWeight', () {
    test('measured minus tare, clamped to zero', () {
      expect(WeighMath.remainingWeight(250, 120), 130);
      expect(WeighMath.remainingWeight(100, 200), 0);
      expect(WeighMath.remainingWeight(120, 120), 0);
    });

    test('NaN inputs yield zero', () {
      expect(WeighMath.remainingWeight(double.nan, 100), 0);
      expect(WeighMath.remainingWeight(250, double.nan), 0);
    });
  });

  group('WeighMath.parseWeight', () {
    test('parses valid numbers', () {
      expect(WeighMath.parseWeight('250', 0), 250);
      expect(WeighMath.parseWeight(' 12.5 ', 0), 12.5);
    });

    test('falls back on blank or invalid', () {
      expect(WeighMath.parseWeight(null, 7), 7);
      expect(WeighMath.parseWeight('', 7), 7);
      expect(WeighMath.parseWeight('abc', 7), 7);
    });
  });

  group('WeighMath.isValidWeight', () {
    test('accepts finite non-negative numbers', () {
      expect(WeighMath.isValidWeight('0'), true);
      expect(WeighMath.isValidWeight('250'), true);
      expect(WeighMath.isValidWeight('12.5'), true);
    });

    test('rejects negatives, NaN, blank, garbage', () {
      expect(WeighMath.isValidWeight('-1'), false);
      expect(WeighMath.isValidWeight(null), false);
      expect(WeighMath.isValidWeight(''), false);
      expect(WeighMath.isValidWeight('abc'), false);
    });
  });
}
