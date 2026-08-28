import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/utils/currency_formatter.dart';
import 'package:bizmanager/core/utils/date_formatter.dart';

void main() {
  group('Globalization - CurrencyFormatter Multi-Currency Tests', () {
    test('Formats PKR amount with default separators and 2 decimal places', () {
      final formatted = CurrencyFormatter.format(
        1234567.89,
        currencyCode: 'PKR',
        decimalPlaces: 2,
        thousandSeparator: ',',
        decimalSeparator: '.',
        symbol: 'Rs.',
      );
      expect(formatted, contains('Rs.'));
      expect(formatted, contains('1,234,567.89'));
    });

    test('Formats USD amount with \$ symbol', () {
      final formatted = CurrencyFormatter.format(
        1234567.89,
        currencyCode: 'USD',
        decimalPlaces: 2,
        thousandSeparator: ',',
        decimalSeparator: '.',
        symbol: '\$',
      );
      expect(formatted, contains('\$'));
      expect(formatted, contains('1,234,567.89'));
    });

    test(
        'Formats European EUR amount with period thousand separator and comma decimal',
        () {
      final formatted = CurrencyFormatter.format(
        1234567.89,
        currencyCode: 'EUR',
        decimalPlaces: 2,
        thousandSeparator: '.',
        decimalSeparator: ',',
        symbol: '€',
      );
      expect(formatted, contains('€'));
      expect(formatted, contains('1.234.567,89'));
    });

    test('Formats JPY zero-decimal amount without trailing decimals', () {
      final formatted = CurrencyFormatter.format(
        1234567,
        currencyCode: 'JPY',
        decimalPlaces: 0,
        thousandSeparator: ',',
        decimalSeparator: '.',
        symbol: '¥',
      );
      expect(formatted, contains('¥'));
      expect(formatted, contains('1,234,567'));
      expect(formatted.contains('.00'), isFalse);
    });
  });

  group('Globalization - DateFormatter Multi-Format Tests', () {
    test('Formats ISO date string as DD/MM/YYYY', () {
      final formatted =
          DateFormatter.format('2026-08-28', format: 'dd/MM/yyyy');
      expect(formatted, equals('28/08/2026'));
    });

    test('Formats ISO date string as MM/DD/YYYY', () {
      final formatted =
          DateFormatter.format('2026-08-28', format: 'MM/dd/yyyy');
      expect(formatted, equals('08/28/2026'));
    });

    test('Formats ISO date string as YYYY-MM-DD', () {
      final formatted =
          DateFormatter.format('2026-08-28', format: 'yyyy-MM-dd');
      expect(formatted, equals('2026-08-28'));
    });
  });

  group('Globalization - Multi-Company Isolation Tests', () {
    test(
        'Switching between Company A (PKR) and Company B (USD) isolates formatting',
        () {
      final companyA = {
        'currency_code': 'PKR',
        'currency_symbol': 'Rs.',
        'decimal_places': 2,
        'thousand_separator': ',',
        'decimal_separator': '.',
        'date_format': 'dd/MM/yyyy',
      };

      final companyB = {
        'currency_code': 'USD',
        'currency_symbol': '\$',
        'decimal_places': 2,
        'thousand_separator': ',',
        'decimal_separator': '.',
        'date_format': 'MM/dd/yyyy',
      };

      final formattedA = CurrencyFormatter.format(
        5000.0,
        currencyCode: companyA['currency_code'] as String,
        decimalPlaces: companyA['decimal_places'] as int,
        symbol: companyA['currency_symbol'] as String,
      );

      final dateA = DateFormatter.format('2026-08-28',
          format: companyA['date_format'] as String);

      final formattedB = CurrencyFormatter.format(
        5000.0,
        currencyCode: companyB['currency_code'] as String,
        decimalPlaces: companyB['decimal_places'] as int,
        symbol: companyB['currency_symbol'] as String,
      );

      final dateB = DateFormatter.format('2026-08-28',
          format: companyB['date_format'] as String);

      expect(formattedA, contains('Rs.'));
      expect(dateA, equals('28/08/2026'));

      expect(formattedB, contains('\$'));
      expect(dateB, equals('08/28/2026'));
    });
  });
}
