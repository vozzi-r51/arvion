import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  /// Formats a DateTime or ISO date string according to the company's preferred date format.
  /// Formats: 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'
  static String formatDate(dynamic dateInput, {String pattern = 'dd/MM/yyyy'}) {
    if (dateInput == null) return '';
    DateTime? dt;
    if (dateInput is DateTime) {
      dt = dateInput;
    } else if (dateInput is String) {
      dt = DateTime.tryParse(dateInput);
    }
    if (dt == null) return dateInput.toString();
    try {
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }

  /// Formats a currency amount with symbol, decimal places, and number style.
  /// decimals: 0 (for PKR/round), 2 (for USD/EUR)
  /// style: 'standard' (1,000.00) vs 'european' (1.000,00)
  static String formatCurrency(
    double amount, {
    String symbol = 'Rs.',
    int decimals = 2,
    String style = 'standard',
  }) {
    final absAmount = amount.abs();
    String formattedNum;

    if (style == 'european') {
      // 1.000,00
      final pattern = decimals == 0 ? '#,##0' : '#,##0.' + ('0' * decimals);
      final formatter = NumberFormat(pattern, 'de_DE');
      formattedNum = formatter.format(absAmount);
    } else {
      // 1,000.00
      final pattern = decimals == 0 ? '#,##0' : '#,##0.' + ('0' * decimals);
      final formatter = NumberFormat(pattern, 'en_US');
      formattedNum = formatter.format(absAmount);
    }

    final sign = amount < 0 ? '-' : '';
    return symbol.isEmpty ? '$sign$formattedNum' : '$sign$symbol $formattedNum';
  }
}
