import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../database/db_helper.dart';

/// Provider that manages company localization settings (currency, date format, language).
/// Exposes formatter methods that respect company preferences.
///
/// Phase 58 — also acts as the app's [LocaleProvider] surface: persists the
/// selected language in [SharedPreferences] so it survives cold starts, and
/// exposes a reactive [Locale] for [MaterialApp.locale].
class LocalizationProvider extends ChangeNotifier {
  Map<String, dynamic>? _company;
  String _locale = 'en';

  /// SharedPreferences key under which the selected language is persisted.
  static const _prefsLocaleKey = 'selected_language';

  String get currencyCode => _company?['currency_code'] as String? ?? 'PKR';
  String get currencySymbol => _company?['currency_symbol'] as String? ?? 'Rs.';
  int get decimalPlaces => _company?['decimal_places'] as int? ?? 2;
  String get thousandSeparator =>
      _company?['thousand_separator'] as String? ?? ',';
  String get decimalSeparator =>
      _company?['decimal_separator'] as String? ?? '.';
  String get dateFormat => _company?['date_format'] as String? ?? 'dd/MM/yyyy';
  String get locale => _locale;

  /// Reactive [Locale] for [MaterialApp.locale]. Returns [Locale('en')]
  /// when no language has been selected or when the stored value is invalid.
  Locale get appLocale {
    switch (_locale) {
      case 'ur':
        return const Locale('ur');
      case 'ar':
        return const Locale('ar');
      case 'en':
      default:
        return const Locale('en');
    }
  }

  /// Initialize: load persisted language first, then overlay with the
  /// active company's `locale_language` (so users who never opened
  /// Settings still get the right default once they pick a company).
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getString(_prefsLocaleKey);
      if (persisted != null && persisted.isNotEmpty) {
        _locale = persisted;
      }
    } catch (_) {
      // SharedPreferences failure is non-fatal — fall back to default.
    }
    try {
      _company = await DBHelper.instance.getActiveCompany();
      final companyLocale = _company?['locale_language'] as String?;
      // Only honor company default if user hasn't picked one explicitly.
      if (_locale == 'en' && companyLocale != null && companyLocale.isNotEmpty) {
        _locale = companyLocale;
      }
    } catch (_) {
      // DB failure is non-fatal at boot — keep current locale.
    }
    notifyListeners();
  }

  /// Update company (when user changes company)
  void setCompany(Map<String, dynamic> company) {
    _company = company;
    notifyListeners();
  }

  /// Set locale/language. Persists to SharedPreferences and notifies
  /// listeners so [MaterialApp.locale] rebuilds immediately.
  Future<void> setLocale(String newLocale) async {
    if (newLocale == _locale) return;
    _locale = newLocale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLocaleKey, newLocale);
    } catch (_) {
      // Persisting failed — in-memory state is still updated, so the
      // current session keeps the new language. Next launch will revert
      // to the previous persisted value.
    }
    notifyListeners();
  }

  /// Format amount as currency using company settings
  String formatCurrency(num amount) {
    return CurrencyFormatter.format(
      amount,
      currencyCode: currencyCode,
      symbol: currencySymbol,
      decimalPlaces: decimalPlaces,
      thousandSeparator: thousandSeparator,
      decimalSeparator: decimalSeparator,
      locale: locale,
    );
  }

  /// Format date using company settings
  String formatDate(String dateStr) {
    return DateFormatter.format(
      dateStr,
      format: dateFormat,
      locale: locale,
    );
  }

  /// Format DateTime using company settings
  String formatDateTime(DateTime date) {
    return DateFormatter.formatDateTime(
      date,
      format: dateFormat,
      locale: locale,
    );
  }
}
