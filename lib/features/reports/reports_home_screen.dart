import 'package:flutter/material.dart';
import 'sales_report_screen.dart';
import 'purchase_report_screen.dart';
import 'profit_report_screen.dart';
import 'expense_report_screen.dart';
import 'stock_report_screen.dart';
import 'customer_report_screen.dart';
import 'supplier_report_screen.dart';
import '../shell/main_shell.dart';

class _ReportTile {
  final String title;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  const _ReportTile(this.title, this.icon, this.color, this.builder);
}

class ReportsHomeScreen extends StatelessWidget {
  final int companyId;
  const ReportsHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ReportTile('Sales Report', Icons.point_of_sale, Colors.teal,
          (_) => SalesReportScreen(companyId: companyId)),
      _ReportTile('Purchase Report', Icons.shopping_cart, Colors.indigo,
          (_) => PurchaseReportScreen(companyId: companyId)),
      _ReportTile('Profit & Loss', Icons.trending_up, Colors.green,
          (_) => ProfitReportScreen(companyId: companyId)),
      _ReportTile('Expense Report', Icons.receipt_long, Colors.orange,
          (_) => ExpenseReportScreen(companyId: companyId)),
      _ReportTile('Stock Report', Icons.inventory_2, Colors.brown,
          (_) => StockReportScreen(companyId: companyId)),
      _ReportTile('Customer Report', Icons.people, Colors.red,
          (_) => CustomerReportScreen(companyId: companyId)),
      _ReportTile('Supplier Report', Icons.local_shipping, Colors.purple,
          (_) => SupplierReportScreen(companyId: companyId)),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Reports'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tiles.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemBuilder: (ctx, i) {
          final tile = tiles[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: tile.builder)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tile.icon, color: tile.color, size: 28),
                    const SizedBox(height: 10),
                    Text(
                      tile.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
