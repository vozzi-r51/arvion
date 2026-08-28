import 'dart:math';

/// Pakistan FBR (Federal Board of Revenue) Digital POS Invoicing Service.
/// Generates 18-digit FBR Invoice Numbers & FBR Compliant QR Code Payloads.
class FbrInvoicingService {
  FbrInvoicingService._();

  /// Generates an 18-digit FBR POS Fiscal Invoice Number.
  /// Format: [POS_ID (6 digits)] + [YYYYMMDD] + [Random/Seq (4 digits)]
  static String generateFbrInvoiceNumber({required String posId}) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomDigits = (1000 + Random().nextInt(9000)).toString();
    final cleanPosId = posId.padLeft(6, '0').substring(0, 6);
    return '$cleanPosId$dateStr$randomDigits';
  }

  /// Constructs FBR compliant QR Code Payload string for thermal receipt printing.
  /// FBR QR Format: FBRInvoiceNumber|USIN|POSID|DateTime|TotalAmount|SalesTaxAmount|PNTN
  static String buildFbrQrPayload({
    required String fbrInvoiceNumber,
    required String usin, // Unique System Invoice Number
    required String posId,
    required double totalAmount,
    required double salesTaxAmount,
    String pntn = '7000000-0', // Pakistan National Tax Number
  }) {
    final dtStr = DateTime.now().toIso8601String().substring(0, 19);
    return '$fbrInvoiceNumber|$usin|$posId|$dtStr|${totalAmount.toStringAsFixed(2)}|${salesTaxAmount.toStringAsFixed(2)}|$pntn';
  }

  /// Verifies if an FBR Invoice Number is syntactically valid (18 digits).
  static bool isValidFbrInvoiceNumber(String fbrNum) {
    final regExp = RegExp(r'^\d{18}$');
    return regExp.hasMatch(fbrNum);
  }
}
