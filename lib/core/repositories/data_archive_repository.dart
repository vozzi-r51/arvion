import 'base_repository.dart';
import '../audit/audit_logger.dart';

/// Database Sharding & Year Archiving Repository.
/// Moves legacy transactions older than N years from main operational tables
/// into archive tables to keep active queries blazingly fast at scale (100,000+ sales).
class DataArchiveRepository extends BaseRepository {
  DataArchiveRepository();

  /// Ensures archive tables exist in database.
  Future<void> _ensureArchiveTablesExist() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_archive (
        id INTEGER PRIMARY KEY,
        company_id INTEGER NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        sale_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL,
        tax REAL NOT NULL,
        total REAL NOT NULL,
        paid_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        is_voided INTEGER NOT NULL DEFAULT 0,
        archived_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases_archive (
        id INTEGER PRIMARY KEY,
        company_id INTEGER NOT NULL,
        supplier_id INTEGER,
        supplier_name TEXT,
        purchase_date TEXT NOT NULL,
        total REAL NOT NULL,
        paid_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        archived_at TEXT NOT NULL
      )
    ''');
  }

  /// Archive sales and purchases older than a specified year (e.g. older than 2024).
  Future<Map<String, int>> archiveTransactionsOlderThanYear({
    required int companyId,
    required int
        cutoffYear, // e.g. 2024 (archives everything from 2023 and earlier)
  }) async {
    await _ensureArchiveTablesExist();
    final cutoffDate = '$cutoffYear-01-01 00:00:00';
    int archivedSalesCount = 0;
    int archivedPurchasesCount = 0;

    await runInTransaction((txn) async {
      // 1. Fetch sales older than cutoff
      final oldSales = await txn.query(
        'sales',
        where: 'company_id = ? AND sale_date < ?',
        whereArgs: [companyId, cutoffDate],
      );

      for (final sale in oldSales) {
        final saleMap = Map<String, dynamic>.from(sale);
        saleMap['archived_at'] = DateTime.now().toIso8601String();
        await txn.insert('sales_archive', saleMap);
        await txn.delete('sales', where: 'id = ?', whereArgs: [sale['id']]);
        archivedSalesCount++;
      }

      // 2. Fetch purchases older than cutoff
      final oldPurchases = await txn.query(
        'purchases',
        where: 'company_id = ? AND purchase_date < ?',
        whereArgs: [companyId, cutoffDate],
      );

      for (final purchase in oldPurchases) {
        final purchaseMap = Map<String, dynamic>.from(purchase);
        purchaseMap['archived_at'] = DateTime.now().toIso8601String();
        await txn.insert('purchases_archive', purchaseMap);
        await txn
            .delete('purchases', where: 'id = ?', whereArgs: [purchase['id']]);
        archivedPurchasesCount++;
      }
    });

    await AuditLogger.log(
      companyId: companyId,
      module: 'Archive',
      action: 'archive',
      description:
          'Archived $archivedSalesCount sales and $archivedPurchasesCount purchases older than year $cutoffYear',
      afterValue: {
        'cutoff_year': cutoffYear,
        'archived_sales': archivedSalesCount,
        'archived_purchases': archivedPurchasesCount,
      },
    );

    return {
      'archivedSales': archivedSalesCount,
      'archivedPurchases': archivedPurchasesCount,
    };
  }

  /// Get total count of archived transactions.
  Future<Map<String, int>> getArchiveSummary(int companyId) async {
    await _ensureArchiveTablesExist();

    final sRows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM sales_archive WHERE company_id = ?",
      [companyId],
    );
    final pRows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM purchases_archive WHERE company_id = ?",
      [companyId],
    );

    return {
      'archivedSales': (sRows.first['c'] as num).toInt(),
      'archivedPurchases': (pRows.first['c'] as num).toInt(),
    };
  }
}
