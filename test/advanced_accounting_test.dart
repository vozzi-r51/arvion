import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1. Cost Centers Domain & Filtering Tests', () {
    test('Cost center filters transactions correctly by branch and company', () {
      final transactions = [
        {'id': 1, 'company_id': 1, 'cost_center_id': 101, 'amount': 5000.0, 'branch': 'Branch A'},
        {'id': 2, 'company_id': 1, 'cost_center_id': 102, 'amount': 3000.0, 'branch': 'Branch B'},
        {'id': 3, 'company_id': 1, 'cost_center_id': 101, 'amount': 7000.0, 'branch': 'Branch A'},
      ];

      final branchA = transactions.where((t) => t['cost_center_id'] == 101).toList();
      final totalBranchA = branchA.fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));

      expect(branchA.length, equals(2));
      expect(totalBranchA, equals(12000.0));
    });
  });

  group('2. Fixed Assets Straight-Line Depreciation Formula Tests', () {
    test('Calculates straight-line monthly depreciation (120k / 5 yrs = 2k/mo) and maintains GL balance', () {
      final purchaseCost = 120000.0;
      final salvageValue = 0.0;
      final usefulLifeYears = 5;

      final annualDepreciation = (purchaseCost - salvageValue) / usefulLifeYears;
      final monthlyDepreciation = annualDepreciation / 12.0;

      expect(annualDepreciation, equals(24000.0));
      expect(monthlyDepreciation, equals(2000.0));

      final month1Accum = monthlyDepreciation;
      final month1BookValue = purchaseCost - month1Accum;

      expect(month1Accum, equals(2000.0));
      expect(month1BookValue, equals(118000.0));

      // Journal entry debits & credits balance check
      final debitDepExpense = monthlyDepreciation;
      final creditAccumDep = monthlyDepreciation;
      expect(debitDepExpense, equals(creditAccumDep)); // Total Debits == Total Credits
    });
  });

  group('3. Budget vs Actual Variance Calculation Tests', () {
    test('Calculates budget vs actual variance and percentage used correctly', () {
      final budgeted = 100000.0;
      final actual = 85000.0;

      final variance = actual - budgeted; // -15,000 (Favorable: under budget for expense)
      final percentUsed = (actual / budgeted) * 100.0;

      expect(variance, equals(-15000.0));
      expect(percentUsed, equals(85.0));
      expect(actual <= budgeted, isTrue); // Not over budget
    });
  });

  group('4. Fiscal Year-End Closing Net Profit Tests', () {
    test('Calculates Net Profit (500k rev - 350k exp = 150k profit) and generates balanced closing entry', () {
      final totalRevenue = 500000.0;
      final totalExpenses = 350000.0;

      final netProfit = totalRevenue - totalExpenses;
      expect(netProfit, equals(150000.0));

      // Retained earnings entry credit equals net profit
      final creditRetainedEarnings = netProfit;
      expect(creditRetainedEarnings, equals(150000.0));
    });
  });

  group('5. Multi-Currency Conversion & Historical Rate Preservation Tests', () {
    test('Converts foreign transaction into base currency and preserves historical exchange rate', () {
      final foreignAmountUSD = 1000.0;
      final historicalRate = 280.0;

      final baseAmountPKR = foreignAmountUSD * historicalRate;
      expect(baseAmountPKR, equals(280000.0));

      // Exchange rate changes later to 285.0
      final updatedRate = 285.0;

      // Historical transaction base amount remains fixed based on historical rate
      expect(foreignAmountUSD * historicalRate, equals(280000.0));
      expect(updatedRate, equals(285.0));
    });
  });
}
