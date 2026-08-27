import 'package:intl/intl.dart';

/// Locale-aware currency formatter that respects company settings.
/// Uses the `intl` package NumberFormat.currency() to handle:
/// - Currency symbol & code (ISO 4217)
/// - Decimal places
/// - Thousand & decimal separators
/// - Locale-specific formatting
class CurrencyFormatter {
  /// Format a number as currency using company settings.
  ///
  /// Parameters:
  ///   - amount: The numeric value to format
  ///   - currencyCode: ISO 4217 code (e.g., 'PKR', 'USD', 'AED', 'INR')
  ///   - decimalPlaces: Number of decimal places (default 2)
  ///   - thousandSeparator: Thousand separator char (default ',')
  ///   - decimalSeparator: Decimal separator char (default '.')
  ///   - locale: BCP 47 language tag (e.g., 'en', 'ur', 'ar')
  ///   - symbol: Override symbol (if not using code)
  static String format(
    num amount, {
    required String currencyCode,
    int decimalPlaces = 2,
    String thousandSeparator = ',',
    String decimalSeparator = '.',
    String locale = 'en',
    String? symbol,
  }) {
    try {
      final nf = NumberFormat.currency(
        locale: '${locale}_US', // Fallback to US locale, will override pattern
        symbol: symbol ?? currencyCode,
        decimalDigits: decimalPlaces,
      );

      // Format the number
      String formatted = nf.format(amount);

      // If separators don't match defaults, replace them
      if (thousandSeparator != ',' || decimalSeparator != '.') {
        // NumberFormat uses ',' and '.' by default
        formatted = formatted.replaceAll(',', '|TEMP|'); // Temp marker
        formatted = formatted.replaceAll('.', decimalSeparator);
        formatted = formatted.replaceAll('|TEMP|', thousandSeparator);
      }

      return formatted;
    } catch (e) {
      // Fallback: basic formatting
      return _basicFormat(amount, decimalPlaces, thousandSeparator, decimalSeparator, symbol ?? currencyCode);
    }
  }

  /// Parse a formatted currency string back to a number.
  /// Removes symbol, separators, and returns the numeric value.
  static double parse(String formatted) {
    // Remove common currency symbols
    String cleaned = formatted
        .replaceAll(RegExp(r'[^\d.,\-]'), '') // Keep only digits, separators, minus
        .trim();

    // Detect separator usage: if comma before period, comma is thousand separator
    final lastComma = cleaned.lastIndexOf(',');
    final lastPeriod = cleaned.lastIndexOf('.');

    String numStr;
    if (lastComma > lastPeriod) {
      // Comma is decimal separator: "1.234,56" → replace comma with dot
      numStr = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Period is decimal separator: "1,234.56" → remove comma
      numStr = cleaned.replaceAll(',', '');
    }

    return double.tryParse(numStr) ?? 0.0;
  }

  /// Format without symbol (numeric value only with separators)
  static String formatNumber(
    num amount, {
    int decimalPlaces = 2,
    String thousandSeparator = ',',
    String decimalSeparator = '.',
  }) {
    return _basicFormat(amount, decimalPlaces, thousandSeparator, decimalSeparator, '');
  }

  /// Helper: basic formatting without intl dependency
  static String _basicFormat(
    num amount,
    int decimalPlaces,
    String thousandSeparator,
    String decimalSeparator,
    String symbol,
  ) {
    final parts = amount.toStringAsFixed(decimalPlaces).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '0' * decimalPlaces;

    // Add thousand separators
    String intFormatted = '';
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        intFormatted += thousandSeparator;
      }
      intFormatted += intPart[i];
    }

    final result = '$intFormatted$decimalSeparator$decPart';
    return symbol.isNotEmpty ? '$symbol $result' : result;
  }
}
