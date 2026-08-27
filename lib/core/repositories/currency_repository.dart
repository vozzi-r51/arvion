import 'base_repository.dart';

/// Repository for Multi-Currency Exchange Rates & Revaluation.
class CurrencyRepository extends BaseRepository {
  CurrencyRepository();

  /// Save or update exchange rate for a foreign currency relative to PKR/Base currency.
  Future<void> setCurrencyRate({
    required int companyId,
    required String currencyCode, // "USD", "EUR", "AED", "SAR", "GBP"
    required String currencySymbol, // "$", "€", "AED", "SR", "£"
    required double exchangeRateToBase, // e.g. 1 USD = 278.5 PKR
  }) async {
    await db.rawInsert('''
      INSERT INTO currency_rates (company_id, currency_code, currency_symbol, exchange_rate_to_base, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(company_id, currency_code) DO UPDATE SET
        currency_symbol = excluded.currency_symbol,
        exchange_rate_to_base = excluded.exchange_rate_to_base,
        updated_at = excluded.updated_at
    ''', [
      companyId,
      currencyCode.toUpperCase(),
      currencySymbol,
      exchangeRateToBase,
      DateTime.now().toIso8601String()
    ]);
  }

  /// Get all configured currencies & rates for a company.
  Future<List<Map<String, dynamic>>> listCurrencyRates(int companyId) async {
    return await db.query(
      'currency_rates',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'currency_code ASC',
    );
  }

  /// Get rate for a specific currency.
  Future<double> getExchangeRate(int companyId, String currencyCode) async {
    if (currencyCode.toUpperCase() == 'PKR' || currencyCode.isEmpty) return 1.0;
    final rows = await db.query(
      'currency_rates',
      where: 'company_id = ? AND currency_code = ?',
      whereArgs: [companyId, currencyCode.toUpperCase()],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return (rows.first['exchange_rate_to_base'] as num).toDouble();
    }
    return 1.0;
  }
}
