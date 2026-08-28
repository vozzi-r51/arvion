/// Pharmacy Batch & Expiry Enforcement Service.
class PharmacyBatchService {
  PharmacyBatchService._();

  /// Validates pharmacy batch creation/update requirements.
  /// Throws FormatException if batch_number or expiry_date is missing.
  static void validatePharmacyBatch({
    required String? batchNumber,
    required String? expiryDate,
  }) {
    final cleanBatch = (batchNumber ?? '').trim();
    if (cleanBatch.isEmpty) {
      throw const FormatException(
          'Batch number is required for pharmacy products.');
    }

    final cleanExpiry = (expiryDate ?? '').trim();
    if (cleanExpiry.isEmpty) {
      throw const FormatException(
          'Expiry date is required for pharmacy products.');
    }

    try {
      DateTime.parse(cleanExpiry);
    } catch (_) {
      throw const FormatException(
          'Invalid expiry date format. Use YYYY-MM-DD.');
    }
  }

  /// Evaluates batch expiry status.
  /// Returns 'expired', 'expiring_soon', or 'valid'.
  static String evaluateExpiryStatus(String expiryDateStr,
      {int warningDaysThreshold = 30}) {
    DateTime expiryDate;
    try {
      expiryDate = DateTime.parse(expiryDateStr);
    } catch (_) {
      return 'valid';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    if (expiry.isBefore(today)) {
      return 'expired';
    }

    final daysRemaining = expiry.difference(today).inDays;
    if (daysRemaining <= warningDaysThreshold) {
      return 'expiring_soon';
    }

    return 'valid';
  }
}
