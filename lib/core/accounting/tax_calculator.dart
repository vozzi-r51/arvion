class CalculatedTaxLine {
  final String taxRateId;
  final String accountId;
  final String taxName;
  final double rate;
  final double taxableAmount;
  final double taxAmount;
  final bool isWithholding;

  CalculatedTaxLine({
    required this.taxRateId,
    required this.accountId,
    required this.taxName,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
    required this.isWithholding,
  });
}

class TaxCalculationResult {
  final double grossAmount;
  final double totalOutputTax;
  final double totalWithholdingTax;
  final double netReceivableOrPayable;
  final List<CalculatedTaxLine> taxLines;

  TaxCalculationResult({
    required this.grossAmount,
    required this.totalOutputTax,
    required this.totalWithholdingTax,
    required this.netReceivableOrPayable,
    required this.taxLines,
  });
}

class TaxCalculator {
  static TaxCalculationResult computeTaxes({
    required double baseAmount,
    required List<Map<String, dynamic>> appliedTaxRates,
  }) {
    double totalOutputTax = 0.0;
    double totalWithholdingTax = 0.0;
    final List<CalculatedTaxLine> taxLines = [];

    for (final rateMap in appliedTaxRates) {
      final double rate = (rateMap['rate'] as num).toDouble();
      final String calculationType =
          rateMap['calculation_type'] as String? ?? 'PERCENTAGE';
      final String taxType = rateMap['tax_type'] as String? ?? 'OUTPUT_TAX';
      final bool isWithholding = taxType == 'WITHHOLDING';

      double taxAmount = 0.0;
      if (calculationType == 'PERCENTAGE') {
        taxAmount = (baseAmount * rate) / 100.0;
      } else if (calculationType == 'FIXED_AMOUNT') {
        taxAmount = rate;
      }

      if (isWithholding) {
        totalWithholdingTax += taxAmount;
      } else {
        totalOutputTax += taxAmount;
      }

      taxLines.add(CalculatedTaxLine(
        taxRateId: rateMap['tax_rate_id']?.toString() ?? '',
        accountId: rateMap['account_id']?.toString() ?? '',
        taxName: rateMap['name'] as String? ?? 'Tax',
        rate: rate,
        taxableAmount: baseAmount,
        taxAmount: taxAmount,
        isWithholding: isWithholding,
      ));
    }

    final double netTotal = baseAmount + totalOutputTax - totalWithholdingTax;

    return TaxCalculationResult(
      grossAmount: baseAmount,
      totalOutputTax: totalOutputTax,
      totalWithholdingTax: totalWithholdingTax,
      netReceivableOrPayable: netTotal,
      taxLines: taxLines,
    );
  }
}
