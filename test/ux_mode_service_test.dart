import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/services/ux_mode_service.dart';

void main() {
  group('UXMode & Progressive Disclosure Unit Tests', () {
    test('UXMode enum properties and descriptions', () {
      expect(UXMode.simple.displayName, equals('Simple'));
      expect(UXMode.advanced.displayName, equals('Advanced'));

      expect(UXMode.simple.description, contains('everyday business management'));
      expect(UXMode.advanced.description, contains('variants'));
    });

    test('UXModeService cache clearing works', () {
      UXModeService.clearCache();
      // Service initialized safely
      expect(UXModeService.clearCache, returnsNormally);
    });
  });
}
