import 'package:flutter/material.dart';
import '../finance/finance_home_screen.dart';
import '../ledger/cash_book_screen.dart';
import '../ledger/bank_accounts_screen.dart';
import '../reports/reports_home_screen.dart';
import '../hr/employee_list_screen.dart';
import '../committee/committee_list_screen.dart';
import '../cheque/cheque_home_screen.dart';
import '../returns/returns_home_screen.dart';
import '../challan/challans_list_screen.dart';
import '../purchase_order/purchase_orders_list_screen.dart';
import '../audit/audit_log_screen.dart';
import '../products/stock_adjustment_screen.dart';
import '../journal/journal_home_screen.dart';
import '../recycle_bin/recycle_bin_screen.dart';

class _MoreMenuItem {
  final String title;
  final IconData icon;
  final bool available;
  final String phaseNote;
  const _MoreMenuItem(this.title, this.icon, this.available, this.phaseNote);
}

class MoreMenuScreen extends StatelessWidget {
  final int companyId;
  const MoreMenuScreen({super.key, required this.companyId});

  static const _upcoming = <_MoreMenuItem>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.bar_chart, color: Colors.white),
              ),
              title: const Text('Reports'),
              subtitle: const Text('Sales, Purchase, P&L, Stock, Customer & Supplier'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportsHomeScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.receipt_long, color: Colors.white),
              ),
              title: const Text('Expenses & Income'),
              subtitle: const Text('Daily expenses, other income, categories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FinanceHomeScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.point_of_sale_outlined, color: Colors.white),
              ),
              title: const Text('Cash Book'),
              subtitle: const Text('Manual cash in / cash out entries'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CashBookScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.indigo,
                child: Icon(Icons.account_balance, color: Colors.white),
              ),
              title: const Text('Bank Book'),
              subtitle: const Text('Bank accounts, deposits, withdrawals'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BankAccountsScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.brown,
                child: Icon(Icons.badge, color: Colors.white),
              ),
              title: const Text('Employees / HR'),
              subtitle: const Text('Attendance, salary, advance, commission'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EmployeeListScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.groups, color: Colors.white),
              ),
              title: const Text('Committee (BC System)'),
              subtitle: const Text('Members, monthly installments, draws'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CommitteeListScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.receipt_long, color: Colors.white),
              ),
              title: const Text('Cheque Management'),
              subtitle: const Text('Received & issued cheques, status tracking'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChequeHomeScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.keyboard_return, color: Colors.white),
              ),
              title: const Text('Returns'),
              subtitle: const Text('Sales return & purchase return'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReturnsHomeScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.local_shipping, color: Colors.white),
              ),
              title: const Text('Delivery Challan'),
              subtitle: const Text('Delivery note, customer signature, tracking'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChallansListScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.cyan,
                child: Icon(Icons.description_outlined, color: Colors.white),
              ),
              title: const Text('Purchase Order'),
              subtitle: const Text('Create PO, approvals, PO history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PurchaseOrdersListScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.history, color: Colors.white),
              ),
              title: const Text('Audit Log'),
              subtitle: const Text('Login history, adds/edits/deletes, stock changes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuditLogScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.brown,
                child: Icon(Icons.tune, color: Colors.white),
              ),
              title: const Text('Inventory Adjustment'),
              subtitle: const Text('Increase, decrease, damage, lost stock'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockAdjustmentScreen(companyId: companyId),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.menu_book, color: Colors.white),
              ),
              title: const Text('Journal & Accounts'),
              subtitle: const Text('Journal entries, Trial Balance, Balance Sheet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => JournalHomeScreen(companyId: companyId)),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.delete_outline, color: Colors.white),
              ),
              title: const Text('Recycle Bin'),
              subtitle: const Text('Deleted products, customers, suppliers, employees'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RecycleBinScreen(companyId: companyId)),
              ),
            ),
          ),
          if (_upcoming.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text('Aane Wale Modules',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ..._upcoming.map((item) => Card(
                  child: ListTile(
                    leading: Icon(item.icon, color: Colors.grey),
                    title: Text(item.title, style: const TextStyle(color: Colors.grey)),
                    trailing: Text(item.phaseNote,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
