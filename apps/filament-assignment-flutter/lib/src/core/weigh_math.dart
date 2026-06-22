/// Pure, testable helpers for the weigh flow.
class WeighMath {
  WeighMath._();

  static double remainingWeight(
    double measuredWeight,
    double emptySpoolWeight,
  ) {
    if (measuredWeight.isNaN || emptySpoolWeight.isNaN) return 0;
    final r = measuredWeight - emptySpoolWeight;
    return r < 0 ? 0 : r;
  }

  /// Parse a weight string to double, returning [fallback] when blank/invalid.
  static double parseWeight(String? value, double fallback) {
    if (value == null) return fallback;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    final parsed = double.tryParse(trimmed);
    return parsed ?? fallback;
  }

  /// True when the trimmed value is a parseable, finite, non-negative number.
  static bool isValidWeight(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final d = double.tryParse(trimmed);
    return d != null && d.isFinite && d >= 0;
  }
}
