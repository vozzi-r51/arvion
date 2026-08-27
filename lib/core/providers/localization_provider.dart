import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../database/db_helper.dart';

/// Provider that manages company localization settings (currency, date format, language).
/// Exposes formatter methods that respect company preferences.
class LocalizationProvider extends ChangeNotifier {
  Map<String, dynamic>? _company;
  String _locale = 'en';

  String get currencyCode => _company?['currency_code'] as String? ?? 'PKR';
  String get currencySymbol => _company?['currency_symbol'] as String? ?? 'Rs.';
  int get decimalPlaces => _company?['decimal_places'] as int? ?? 2;
  String get thousandSeparator => _company?['thousand_separator'] as String? ?? ',';
  String get decimalSeparator => _company?['decimal_separator'] as String? ?? '.';
  String get dateFormat => _company?['date_format'] as String? ?? 'dd/MM/yyyy';
  String get locale => _locale;

  /// Initialize with active company
  Future<void> init() async {
    _company = await DBHelper.instance.getActiveCompany();
    _locale = _company?['locale_language'] as String? ?? 'en';
    notifyListeners();
  }

  /// Update company (when user changes company)
  void setCompany(Map<String, dynamic> company) {
    _company = company;
    _locale = company['locale_language'] as String? ?? 'en';
    notifyListeners();
  }

  /// Set locale/language
  void setLocale(String newLocale) {
    _locale = newLocale;
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
