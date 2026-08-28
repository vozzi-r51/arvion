import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

enum UXMode {
  simple,
  advanced;

  String get displayName {
    switch (this) {
      case UXMode.simple:
        return 'Simple';
      case UXMode.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case UXMode.simple:
        return 'Everything you need for everyday business management, without unnecessary complexity.';
      case UXMode.advanced:
        return 'Unlock powerful features such as variants, custom fields, multi-unit measurements, advanced taxes, and manufacturing.';
    }
  }
}

/// Advanced Feature Detection Engine.
/// Inspects existing database records for evidence of advanced feature usage.
class AdvancedFeatureDetector {
  AdvancedFeatureDetector._();

  /// Efficiently detects if a company uses advanced features using lightweight SELECT EXISTS queries.
  static Future<bool> detectAdvancedUsage(int companyId) async {
    try {
      final db = await DBHelper.instance.database;

      // 1. Detect Product Variants
      final variantRows = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM products WHERE company_id = ? AND (has_variants = 1 OR is_serialized = 1)) AS ex',
        [companyId],
      );
      if (Sqflite.firstIntValue(variantRows) == 1) return true;

      // 2. Detect Custom Fields
      final customFieldRows = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM custom_field_definitions WHERE company_id = ?) AS ex',
        [companyId],
      );
      if (Sqflite.firstIntValue(customFieldRows) == 1) return true;

      // 3. Detect Multi-UOM
      final uomRows = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM units_of_measure WHERE company_id = ?) AS ex',
        [companyId],
      );
      if (Sqflite.firstIntValue(uomRows) == 1) return true;

      // 4. Detect Multi-Tax
      final taxRows = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM tax_codes WHERE company_id = ?) AS ex',
        [companyId],
      );
      if (Sqflite.firstIntValue(taxRows) == 1) return true;

      // 5. Detect Manufacturing / BOMs
      final bomRows = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM boms WHERE company_id = ?) AS ex',
        [companyId],
      );
      if (Sqflite.firstIntValue(bomRows) == 1) return true;

      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Centralized UI Mode Management Service.
/// Manages company-specific Simple vs Advanced mode transitions and smart migration.
class UXModeService {
  UXModeService._();

  static const String _prefKey = 'app_ui_mode';
  static final Map<int, UXMode> _memoryCache = {};

  /// Returns effective UI Mode for a company.
  /// Reads from DB companies.ui_mode, runs smart detection for legacy companies, and caches result.
  static Future<UXMode> getEffectiveMode(int companyId) async {
    if (_memoryCache.containsKey(companyId)) {
      return _memoryCache[companyId]!;
    }

    try {
      final company = await DBHelper.instance.getCompanyById(companyId);
      final savedDbMode = company?['ui_mode'] as String?;

      if (savedDbMode == 'advanced') {
        _memoryCache[companyId] = UXMode.advanced;
        return UXMode.advanced;
      }
      if (savedDbMode == 'simple') {
        _memoryCache[companyId] = UXMode.simple;
        return UXMode.simple;
      }

      // Smart Migration for legacy companies
      final isAdvancedUser = await AdvancedFeatureDetector.detectAdvancedUsage(companyId);
      final effectiveMode = isAdvancedUser ? UXMode.advanced : UXMode.simple;

      await setMode(companyId, effectiveMode);
      return effectiveMode;
    } catch (_) {
      return UXMode.simple;
    }
  }

  /// Explicitly sets UI Mode for a company in database and cache.
  static Future<void> setMode(int companyId, UXMode mode) async {
    final modeStr = mode == UXMode.advanced ? 'advanced' : 'simple';
    _memoryCache[companyId] = mode;

    try {
      await DBHelper.instance.updateCompany(companyId, {'ui_mode': modeStr});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_prefKey}_$companyId', modeStr);
    } catch (_) {}
  }

  /// Clears in-memory mode cache when switching companies.
  static void clearCache() {
    _memoryCache.clear();
  }
}
