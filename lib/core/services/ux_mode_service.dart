import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

enum UXMode { simple, advanced }

class UXModeService {
  UXModeService._();

  static const String _prefKey = 'app_ui_mode';

  /// Returns the current UI mode ('simple' or 'advanced').
  /// Auto-detects 'advanced' if the company already uses advanced features.
  static Future<UXMode> getEffectiveMode(int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('${_prefKey}_$companyId');

    if (savedMode == 'simple') return UXMode.simple;
    if (savedMode == 'advanced') return UXMode.advanced;

    // Auto-detect for existing users
    final isAdvancedUser = await _detectAdvancedUsage(companyId);
    if (isAdvancedUser) {
      await prefs.setString('${_prefKey}_$companyId', 'advanced');
      return UXMode.advanced;
    }

    // Default for new users is simple
    return UXMode.simple;
  }

  static Future<void> setMode(int companyId, UXMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefKey}_$companyId', mode == UXMode.advanced ? 'advanced' : 'simple');
  }

  static Future<bool> _detectAdvancedUsage(int companyId) async {
    try {
      final db = await DBHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM products
        WHERE company_id = ? AND (has_variants = 1 OR uom_id IS NOT NULL OR is_serialized = 1)
      ''', [companyId]);
      final count = Sqflite.firstIntValue(rows) ?? 0;
      if (count > 0) return true;

      final customFields = await DBHelper.instance.getCustomFieldDefinitions(companyId, 'product');
      if (customFields.isNotEmpty) return true;

      return false;
    } catch (_) {
      return false;
    }
  }
}
