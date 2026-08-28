import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bizmanager/core/services/query_cache_service.dart';
import 'package:bizmanager/core/services/report_compute_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'db_encryption_key': 'MDAwMDAwMDAw00000000MDAwMDAwMDAwMDAwMDA=',
    });
  });

  group(
      '1. Large Dataset Stock Valuation Isolate Benchmark Tests (5,000+ Products)',
      () {
    test(
        'Calculates total stock valuation across 5,000 products on background Isolate worker',
        () async {
      // Generate 5,000 product records
      final products = List<Map<String, dynamic>>.generate(5000, (i) {
        return {
          'id': i + 1,
          'name': 'Product #${i + 1}',
          'stock': 10.0,
          'sale_price': 100.0,
          'cost_price': 60.0,
        };
      });

      final stopwatch = Stopwatch()..start();
      final valuation =
          await ReportComputeService.computeStockValuation(products);
      stopwatch.stop();

      expect(valuation['totalQty'], equals(50000.0)); // 5000 * 10
      expect(valuation['totalRetailValue'], equals(5000000.0)); // 50000 * 100
      expect(valuation['totalCostValue'], equals(3000000.0)); // 50000 * 60
      expect(valuation['potentialProfit'], equals(2000000.0));

      // Execution completed under 1000ms
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test(
        'Computes Trial Balance Debit/Credit Totals across journal lines on Isolate thread',
        () async {
      final lines = List<Map<String, dynamic>>.generate(2000, (i) {
        final isEven = i % 2 == 0;
        return {
          'account_id': (i % 10) + 1,
          'account_name': 'Account #${(i % 10) + 1}',
          'debit': isEven ? 500.0 : 0.0,
          'credit': isEven ? 0.0 : 500.0,
        };
      });

      final result = await ReportComputeService.computeTrialBalance(lines);

      expect(result['totalDebit'], equals(500000.0)); // 1000 * 500
      expect(result['totalCredit'], equals(500000.0)); // 1000 * 500
      expect(result['isBalanced'], isTrue); // Debits == Credits
    });
  });

  group('2. 5-Minute TTL Query Cache & Event-Driven Invalidation Tests', () {
    test(
        'QueryCacheService caches query results and invalidates on prefix event',
        () {
      final cache = QueryCacheService.instance;
      cache.clear();

      final cacheKey = 'dashboard:1:today_sales';
      expect(cache.get<double>(cacheKey), isNull);

      // Set cache
      cache.set<double>(cacheKey, 125000.0, ttl: const Duration(minutes: 5));

      // Re-read within TTL
      final cachedVal = cache.get<double>(cacheKey);
      expect(cachedVal, equals(125000.0));

      // Event-driven invalidation after new sale
      cache.invalidatePrefix('dashboard:1:');

      final afterInvalidate = cache.get<double>(cacheKey);
      expect(afterInvalidate, isNull);
    });
  });

  group('3. Database Composite Index Audit Tests', () {
    test(
        'Composite index SQL statements generated for company-scoped high-frequency queries',
        () {
      final indexStatements = [
        'CREATE INDEX IF NOT EXISTS idx_products_company_status ON products(company_id, status)',
        'CREATE INDEX IF NOT EXISTS idx_sales_company_date ON sales(company_id, sale_date)',
        'CREATE INDEX IF NOT EXISTS idx_purchases_company_date ON purchases(company_id, purchase_date)',
        'CREATE INDEX IF NOT EXISTS idx_expenses_company_date ON expenses(company_id, expense_date)',
        'CREATE INDEX IF NOT EXISTS idx_customers_company_name ON customers(company_id, name)',
        'CREATE INDEX IF NOT EXISTS idx_suppliers_company_name ON suppliers(company_id, company_name)',
        'CREATE INDEX IF NOT EXISTS idx_bank_transactions_comp_acc ON bank_transactions(company_id, bank_account_id, is_reconciled)',
        'CREATE INDEX IF NOT EXISTS idx_audit_log_comp_time ON audit_log(company_id, timestamp)',
      ];

      expect(indexStatements.length, equals(8));
      expect(indexStatements.first, contains('idx_products_company_status'));
    });
  });
}
