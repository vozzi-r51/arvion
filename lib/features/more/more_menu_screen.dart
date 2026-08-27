import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/auth/session.dart';
import '../../core/database/db_helper.dart';
import '../../core/services/ux_mode_service.dart';
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
import '../promotions/promotions_list_screen.dart';
import '../finance/recurring_templates_screen.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/export/full_data_export_service.dart';
import '../../core/providers/terminology_provider.dart';
import 'package:provider/provider.dart';

class _MoreMenuItem {
  final String title;
  final IconData icon;
  final bool available;
  final String phaseNote;
  const _MoreMenuItem(this.title, this.icon, this.available, this.phaseNote);
}

class MoreMenuScreen extends StatefulWidget {
  final int companyId;
  const MoreMenuScreen({super.key, required this.companyId});

  @override
  State<MoreMenuScreen> createState() => _MoreMenuScreenState();
}

class _MoreMenuScreenState extends State<MoreMenuScreen> {
  List<String> _enabledModules = [];
  UXMode _mode = UXMode.simple;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company != null) {
      final modulesStr = company['enabled_modules'] as String?;
      if (modulesStr != null) {
        try {
          _enabledModules = List<String>.from(jsonDecode(modulesStr));
        } catch (_) {}
      }
    }
    _mode = await UXModeService.getEffectiveMode(widget.companyId);
    setState(() => _loading = false);
  }

  static const _upcoming = <_MoreMenuItem>[];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isOwner = Session.isOwner;
    final term = context.watch<TerminologyProvider>();

    bool isEnabled(String module) => _enabledModules.contains(module.toLowerCase());

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: !isOwner 
        ? const Center(child: Text('Access Denied: Only Owner can access this menu'))
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
          _buildMenuCard(
            context,
            icon: Icons.bar_chart,
            color: Colors.teal,
            title: 'Reports',
            subtitle: 'Sales, Purchase, P&L, Stock, Customer & Supplier',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReportsHomeScreen(companyId: widget.companyId)),
            ),
          ),
          if (isEnabled('expenses'))
          _buildMenuCard(
            context,
            icon: Icons.receipt_long,
            color: Colors.orange,
            title: 'Expenses & Income',
            subtitle: 'Daily expenses, other income, categories',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FinanceHomeScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.point_of_sale_outlined,
            color: Colors.green,
            title: 'Cash Book',
            subtitle: 'Manual cash in / cash out entries',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CashBookScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.account_balance,
            color: Colors.indigo,
            title: 'Bank Book',
            subtitle: 'Bank accounts, deposits, withdrawals',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BankAccountsScreen(companyId: widget.companyId)),
            ),
          ),
          if (isEnabled('hr'))
          _buildMenuCard(
            context,
            icon: Icons.badge,
            color: Colors.brown,
            title: 'Employees / HR',
            subtitle: 'Attendance, salary, advance, commission',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EmployeeListScreen(companyId: widget.companyId)),
            ),
          ),
          if (isEnabled('committee'))
          _buildMenuCard(
            context,
            icon: Icons.groups,
            color: Colors.deepPurple,
            title: 'Committee (BC System)',
            subtitle: 'Members, monthly installments, draws',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CommitteeListScreen(companyId: widget.companyId)),
            ),
          ),
          if (isEnabled('cheque'))
          _buildMenuCard(
            context,
            icon: Icons.receipt_long,
            color: Colors.blueGrey,
            title: 'Cheque Management',
            subtitle: 'Received & issued cheques, status tracking',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChequeHomeScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.keyboard_return,
            color: Colors.red,
            title: 'Returns',
            subtitle: '${term.get('sale')} return & purchase return',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReturnsHomeScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.local_shipping,
            color: Colors.blue,
            title: 'Delivery Challan',
            subtitle: 'Delivery note, customer signature, tracking',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChallansListScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.description_outlined,
            color: Colors.cyan,
            title: 'Purchase Order',
            subtitle: 'Create PO, approvals, PO history',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PurchaseOrdersListScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.history,
            color: Colors.black54,
            title: 'Audit Log',
            subtitle: 'Login history, adds/edits/deletes, stock changes',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AuditLogScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.tune,
            color: Colors.brown,
            title: 'Inventory Adjustment',
            subtitle: 'Increase, decrease, damage, lost stock',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StockAdjustmentScreen(companyId: widget.companyId)),
            ),
          ),
          if (isEnabled('accounting'))
          _buildMenuCard(
            context,
            icon: Icons.menu_book,
            color: Colors.teal,
            title: 'Journal & Accounts',
            subtitle: 'Journal entries, Trial Balance, Balance Sheet',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => JournalHomeScreen(companyId: widget.companyId)),
            ),
          ),
          if (isEnabled('promotions'))
          _buildMenuCard(
            context,
            icon: Icons.local_offer,
            color: Colors.pink,
            title: 'Promotions & Discounts',
            subtitle: 'Manage sales offers and category discounts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PromotionsListScreen(companyId: widget.companyId)),
            ),
          ),
          if (_mode == UXMode.advanced)
          _buildMenuCard(
            context,
            icon: Icons.repeat,
            color: Colors.blueGrey,
            title: 'Recurring Items',
            subtitle: 'Automate monthly rent, bills, or fixed income',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RecurringTemplatesScreen(companyId: widget.companyId)),
            ),
          ),
          if (_mode == UXMode.advanced)
          _buildMenuCard(
            context,
            icon: Icons.delete_outline,
            color: Colors.grey,
            title: 'Recycle Bin',
            subtitle: 'Deleted ${term.get('product')}s, customers, suppliers, employees',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RecycleBinScreen(companyId: widget.companyId)),
            ),
          ),
          _buildMenuCard(
            context,
            icon: Icons.table_view_outlined,
            color: Colors.teal,
            title: 'Full Data Export (CSV)',
            subtitle: 'Products, Customers aur Sales history Excel mein le jayein',
            onTap: () => FullDataExportService.exportAllToCsv(widget.companyId),
          ),
          if (_upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.l, AppSpacing.xs, AppSpacing.s),
              child: Text('Aane Wale Modules',
                  style: AppTypography.labelLarge(context).copyWith(color: Colors.grey)),
            ),
            ..._upcoming.map((item) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  ),
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

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20, semanticLabel: title),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}
