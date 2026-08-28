import 'dart:io';
import '../models/bank_reconciliation_models.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/import/parsers/generic_csv_excel_parser.dart';

class BankStatementParser {
  BankStatementParser();

  static const List<String> _dateAliases = [
    'date', 'transaction date', 'txn date', 'posting date', 'value date'
  ];

  static const List<String> _descAliases = [
    'description', 'narration', 'details', 'transaction details', 'particulars', 'memo'
  ];

  static const List<String> _debitAliases = [
    'debit', 'debit amount', 'withdrawal', 'withdrawals', 'dr'
  ];

  static const List<String> _creditAliases = [
    'credit', 'credit amount', 'deposit', 'deposits', 'cr'
  ];

  static const List<String> _balanceAliases = [
    'balance', 'running balance', 'closing balance', 'available balance'
  ];

  static const List<String> _refAliases = [
    'reference', 'ref no', 'cheque no', 'txn id', 'chq no'
  ];

  /// Parses bank statement CSV/Excel file into normalized `ParsedBankStatementRow`s.
  Future<Map<String, dynamic>> parseStatementFile(String filePath) async {
    final parsed = await GenericCsvExcelParser().parseFile(filePath);
    final List<String> headers = List<String>.from(parsed['headers']);
    final List<Map<String, String>> rawRows = List<Map<String, String>>.from(parsed['rows']);

    // Detect column indexes/names
    String? dateHeader = _findMatchingHeader(headers, _dateAliases);
    String? descHeader = _findMatchingHeader(headers, _descAliases);
    String? debitHeader = _findMatchingHeader(headers, _debitAliases);
    String? creditHeader = _findMatchingHeader(headers, _creditAliases);
    String? balanceHeader = _findMatchingHeader(headers, _balanceAliases);
    String? refHeader = _findMatchingHeader(headers, _refAliases);

    final List<ParsedBankStatementRow> rows = [];

    for (int i = 0; i < rawRows.length; i++) {
      final raw = rawRows[i];
      final dateStr = (dateHeader != null ? raw[dateHeader] : '')?.trim() ?? '';
      final descStr = (descHeader != null ? raw[descHeader] : '')?.trim() ?? '';
      final debitStr = (debitHeader != null ? raw[debitHeader] : '')?.trim() ?? '';
      final creditStr = (creditHeader != null ? raw[creditHeader] : '')?.trim() ?? '';
      final balanceStr = (balanceHeader != null ? raw[balanceHeader] : '')?.trim() ?? '';
      final refStr = (refHeader != null ? raw[refHeader] : '')?.trim() ?? '';

      final debitVal = _parseAmount(debitStr);
      final creditVal = _parseAmount(creditStr);
      final balanceVal = balanceStr.isNotEmpty ? _parseAmount(balanceStr) : null;

      double signedAmount = 0.0;
      if (creditVal > 0) {
        signedAmount = creditVal;
      } else if (debitVal > 0) {
        signedAmount = -debitVal;
      } else {
        // Fallback: check if debitStr or creditStr contains signed amount
        signedAmount = _parseAmount(debitStr.isNotEmpty ? debitStr : creditStr);
      }

      DateTime? parsedDate;
      if (dateStr.isNotEmpty) {
        try {
          parsedDate = DateFormatter.parse(dateStr);
        } catch (_) {}
      }

      final row = ParsedBankStatementRow(
        rowIndex: i + 1,
        dateStr: dateStr,
        parsedDate: parsedDate,
        description: descStr.isNotEmpty ? descStr : 'Bank Transaction #${i + 1}',
        debit: debitVal,
        credit: creditVal,
        amount: signedAmount,
        balance: balanceVal,
        reference: refStr.isNotEmpty ? refStr : null,
      );

      // Validation
      if (dateStr.isEmpty || parsedDate == null) {
        row.validationErrors.add('Missing or invalid transaction date');
      }
      if (signedAmount == 0.0 && debitVal == 0.0 && creditVal == 0.0) {
        row.validationErrors.add('Missing or invalid transaction amount');
      }

      if (!row.isValid) {
        row.status = ParsedRowStatus.invalid;
      }

      rows.add(row);
    }

    return {
      'headers': headers,
      'detectedColumns': {
        'date': dateHeader,
        'description': descHeader,
        'debit': debitHeader,
        'credit': creditHeader,
        'balance': balanceHeader,
        'reference': refHeader,
      },
      'rows': rows,
    };
  }

  static String? _findMatchingHeader(List<String> headers, List<String> aliases) {
    for (final h in headers) {
      final norm = h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      for (final alias in aliases) {
        final normAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
        if (norm == normAlias) return h;
      }
    }
    for (final h in headers) {
      final norm = h.toLowerCase().trim();
      for (final alias in aliases) {
        if (norm.contains(alias.toLowerCase())) return h;
      }
    }
    return null;
  }

  static double _parseAmount(String input) {
    if (input.isEmpty) return 0.0;
    final clean = input.replaceAll(RegExp(r'[^\d.\-]'), '').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
