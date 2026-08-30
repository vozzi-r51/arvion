import 'dart:math';

/// Utility generating standard time-sortable UUIDv7 identifiers.
class UUIDv7 {
  UUIDv7._();

  static final Random _random = Random.secure();

  /// Generate a 36-character UUIDv7 formatted string (e.g. "018c1f9d-7f00-7000-8000-000000000000")
  static String generate() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 48-bit timestamp in hex (12 hex digits)
    final timeHex = nowMs.toRadixString(16).padLeft(12, '0');

    // 12-bit random (version 7 prefix: 0x7 + 3 random hex digits)
    final randA = _random.nextInt(0x0FFF);
    final versionAndRandA = '7${randA.toRadixString(16).padLeft(3, '0')}';

    // Variant 10xx: (0x8..0xB) + 3 random hex digits
    final randBVal = (0x8 | _random.nextInt(4)) << 12 | _random.nextInt(0x0FFF);
    final variantAndRandB = randBVal.toRadixString(16).padLeft(4, '0');

    // Remaining 48 random bits (12 hex digits)
    final randCVal1 = _random.nextInt(0xFFFF);
    final randCVal2 = _random.nextInt(0xFFFF);
    final randCVal3 = _random.nextInt(0xFFFF);
    final randC = randCVal1.toRadixString(16).padLeft(4, '0') +
        randCVal2.toRadixString(16).padLeft(4, '0') +
        randCVal3.toRadixString(16).padLeft(4, '0');

    // Grouping: 8-4-4-4-12
    final part1 = timeHex.substring(0, 8);
    final part2 = timeHex.substring(8, 12);
    final part3 = versionAndRandA;
    final part4 = variantAndRandB;
    final part5 = randC;

    return '$part1-$part2-$part3-$part4-$part5';
  }
}
