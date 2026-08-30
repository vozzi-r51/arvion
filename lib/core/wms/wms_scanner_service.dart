import 'package:sqflite/sqflite.dart';

class WMSScanException implements Exception {
  final String message;
  WMSScanException(this.message);

  @override
  String toString() => 'WMSScanException: $message';
}

class WMSScannerService {
  /// Verifies a scanned barcode against the active Pick List item.
  static Future<bool> verifyPickItem(
    DatabaseExecutor db, {
    required String pickListId,
    required String scannedBarcode,
    required String scannedBinCode,
  }) async {
    // 1. Resolve product & bin
    final itemRows = await db.rawQuery('''
      SELECT pli.item_id, pli.expected_qty, pli.scanned_qty, p.barcode, wb.bin_code
      FROM pick_list_items pli
      JOIN products p ON (pli.product_id = p.id OR pli.product_id = p.product_code OR CAST(pli.product_id AS TEXT) = CAST(p.id AS TEXT))
      JOIN warehouse_bins wb ON (pli.bin_id = wb.bin_id OR pli.bin_id = wb.bin_code)
      WHERE pli.pick_list_id = ? AND (p.barcode = ? OR p.product_code = ? OR p.name = ?) AND wb.bin_code = ?
    ''', [pickListId, scannedBarcode, scannedBarcode, scannedBarcode, scannedBinCode]);

    if (itemRows.isEmpty) {
      throw WMSScanException(
          'Item or Bin mismatch! Verify product barcode and bin location.');
    }

    final item = itemRows.first;
    final double expected = (item['expected_qty'] as num).toDouble();
    final double currentScanned = (item['scanned_qty'] as num).toDouble();
    final double updatedScanned = currentScanned + 1.0;

    if (updatedScanned > expected) {
      throw WMSScanException(
          'Over-pick error: Scanned quantity exceeds required order volume.');
    }

    final int isVerified = (updatedScanned == expected) ? 1 : 0;

    await db.update(
      'pick_list_items',
      {
        'scanned_qty': updatedScanned,
        'is_verified': isVerified,
      },
      where: 'item_id = ?',
      whereArgs: [item['item_id']],
    );

    return isVerified == 1;
  }
}
