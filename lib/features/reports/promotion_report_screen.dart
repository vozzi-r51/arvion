import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class PromotionReportScreen extends StatefulWidget {
  final int companyId;
  const PromotionReportScreen({super.key, required this.companyId});

  @override
  State<PromotionReportScreen> createState() => _PromotionReportScreenState();
}

class _PromotionReportScreenState extends State<PromotionReportScreen> {
  List<Map<String, dynamic>> _reportData = [];
  bool _loading = true;
  String _currencyCode = 'PKR';
  String _currencySymbol = 'Rs.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DBHelper.instance.database;
    final company = await DBHelper.instance.getCompanyById(widget.companyId);

    if (company != null) {
      _currencyCode = company['currency_code'] as String? ?? 'PKR';
      _currencySymbol = company['currency_symbol'] as String? ?? 'Rs.';
    }

    final rows = await db.rawQuery('''
      SELECT p.id, p.name, p.type, p.current_use_count,
             COALESCE(SUM(pu.discount_amount), 0) AS total_discount,
             COUNT(pu.id) AS actual_uses
      FROM promotions p
      LEFT JOIN promotion_usages pu ON p.id = pu.promotion_id
      WHERE p.company_id = ?
      GROUP BY p.id
      ORDER BY p.current_use_count DESC
    ''', [widget.companyId]);

    setState(() {
      _reportData = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotion Performance Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reportData.isEmpty
              ? const AppEmptyState(
                  icon: Icons.local_offer_outlined,
                  title: 'Koi Promotion Data Nahi',
                  message:
                      'Promotions create karein aur sales par apply karein taake usage performance dikhe.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  itemCount: _reportData.length,
                  itemBuilder: (ctx, i) {
                    final item = _reportData[i];
                    final name = item['name'] as String;
                    final type = item['type'] as String;
                    final uses = (item['current_use_count'] as num).toInt();
                    final discount = (item['total_discount'] as num).toDouble();

                    final formattedDiscount = CurrencyFormatter.format(
                      discount,
                      currencyCode: _currencyCode,
                      symbol: _currencySymbol,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.m),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple.shade50,
                              child: Icon(Icons.local_offer,
                                  color: Colors.purple.shade800),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text(
                                      'Type: ${type.toUpperCase()} • Usage: $uses times',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Discount Given',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                Text(formattedDiscount,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
