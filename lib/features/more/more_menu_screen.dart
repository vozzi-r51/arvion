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
import '../finance/fixed_assets_screen.dart';
import '../finance/fiscal_year_closing_screen.dart';
import '../settings/cost_centers_screen.dart';
import '../settings/currency_rates_screen.dart';
import '../settings/ecommerce_channels_screen.dart';
import '../import_export/universal_import_screen.dart';
import '../help/help_center_screen.dart';
import '../changelog/whats_new_screen.dart';
import '../../core/widgets/feedback_dialog.dart';
import '../reports/budget_vs_actual_screen.dart';
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
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isOwner = Session.isOwner;
    final term = context.watch<TerminologyProvider>();

    bool isEnabled(String module) =>
        _enabledModules.contains(module.toLowerCase());

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: !isOwner
          ? const Center(
              child: Text('Access Denied: Only Owner can access this menu'))
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
                    MaterialPageRoute(
                        builder: (_) =>
                            ReportsHomeScreen(companyId: widget.companyId)),
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
                      MaterialPageRoute(
                          builder: (_) =>
                              FinanceHomeScreen(companyId: widget.companyId)),
                    ),
                  ),
                _buildMenuCard(
                  context,
                  icon: Icons.point_of_sale_outlined,
                  color: Colors.green,
                  title: 'Cash Book',
                  subtitle: 'Manual cash in / cash out entries',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            CashBookScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.account_balance,
                  color: Colors.indigo,
                  title: 'Bank Book',
                  subtitle: 'Bank accounts, deposits, withdrawals',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            BankAccountsScreen(companyId: widget.companyId)),
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
                      MaterialPageRoute(
                          builder: (_) =>
                              EmployeeListScreen(companyId: widget.companyId)),
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
                      MaterialPageRoute(
                          builder: (_) =>
                              CommitteeListScreen(companyId: widget.companyId)),
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
                      MaterialPageRoute(
                          builder: (_) =>
                              ChequeHomeScreen(companyId: widget.companyId)),
                    ),
                  ),
                _buildMenuCard(
                  context,
                  icon: Icons.keyboard_return,
                  color: Colors.red,
                  title: 'Returns',
                  subtitle: '${term.get('sale')} return & purchase return',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            ReturnsHomeScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                  title: 'Delivery Challan',
                  subtitle: 'Delivery note, customer signature, tracking',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            ChallansListScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.description_outlined,
                  color: Colors.cyan,
                  title: 'Purchase Order',
                  subtitle: 'Create PO, approvals, PO history',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => PurchaseOrdersListScreen(
                            companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.history,
                  color: Colors.black54,
                  title: 'Audit Log',
                  subtitle: 'Login history, adds/edits/deletes, stock changes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            AuditLogScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.tune,
                  color: Colors.brown,
                  title: 'Inventory Adjustment',
                  subtitle: 'Increase, decrease, damage, lost stock',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            StockAdjustmentScreen(companyId: widget.companyId)),
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
                      MaterialPageRoute(
                          builder: (_) =>
                              JournalHomeScreen(companyId: widget.companyId)),
                    ),
                  ),
                _buildMenuCard(
                  context,
                  icon: Icons.location_city_outlined,
                  color: Colors.indigo,
                  title: 'Branches & Cost Centers',
                  subtitle: 'Manage shop branches, departments & warehouses',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            CostCentersScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.account_balance_outlined,
                  color: Colors.blue,
                  title: 'Fixed Assets & Depreciation',
                  subtitle:
                      'Register equipment/vehicles, straight-line depreciation',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            FixedAssetsScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.pie_chart_outline,
                  color: Colors.deepOrange,
                  title: 'Budget vs Actual Report',
                  subtitle:
                      'Monthly expense category budgets & variance analysis',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            BudgetVsActualScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.lock_clock,
                  color: Colors.purple,
                  title: 'Fiscal Year-End Closing',
                  subtitle:
                      'Close year, transfer Net Profit to Retained Earnings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => FiscalYearClosingScreen(
                            companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.currency_exchange,
                  color: Colors.teal,
                  title: 'Multi-Currency Exchange Rates',
                  subtitle:
                      'USD, EUR, AED, SAR exchange rates for foreign bills',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            CurrencyRatesScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.orange.shade800,
                  title: 'E-commerce Sync (Daraz & WhatsApp)',
                  subtitle:
                      'Sync Daraz Store orders & WhatsApp Business Catalog CSV',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => EcommerceChannelsScreen(
                            companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.file_download_outlined,
                  color: Colors.teal.shade700,
                  title: 'Universal Data Import (Zero Switching Cost)',
                  subtitle:
                      'Import Products, Customers & Vendors from QuickBooks, Tally, Vyapar or Excel',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            UniversalImportScreen(companyId: widget.companyId)),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.help_outline,
                  color: Colors.indigo,
                  title: 'Help & Resource Center',
                  subtitle: 'Searchable FAQ, guides & how-to tutorials',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.auto_awesome,
                  color: Colors.purple,
                  title: "What's New in v2.5",
                  subtitle: 'Changelog, release notes & new feature list',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhatsNewScreen()),
                  ),
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.feedback_outlined,
                  color: Colors.teal,
                  title: 'Suggest a Feature / Feedback',
                  subtitle: 'Send feature requests or report bugs directly',
                  onTap: () => FeedbackDialog.show(context, widget.companyId),
                ),
                if (isEnabled('promotions'))
                  _buildMenuCard(
                    context,
                    icon: Icons.local_offer,
                    color: Colors.pink,
                    title: 'Promotions & Discounts',
                    subtitle: 'Manage sales offers and category discounts',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => PromotionsListScreen(
                              companyId: widget.companyId)),
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
                      MaterialPageRoute(
                          builder: (_) => RecurringTemplatesScreen(
                              companyId: widget.companyId)),
                    ),
                  ),
                if (_mode == UXMode.advanced)
                  _buildMenuCard(
                    context,
                    icon: Icons.delete_outline,
                    color: Colors.grey,
                    title: 'Recycle Bin',
                    subtitle:
                        'Deleted ${term.get('product')}s, customers, suppliers, employees',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              RecycleBinScreen(companyId: widget.companyId)),
                    ),
                  ),
                _buildMenuCard(
                  context,
                  icon: Icons.table_view_outlined,
                  color: Colors.teal,
                  title: 'Full Data Export (CSV/Excel)',
                  subtitle:
                      'Products, Customers, Sales aur 20+ tables export karein',
                  onTap: () => FullDataExportService.exportFullBusinessData(
                      widget.companyId),
                ),
                if (_upcoming.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xs,
                        AppSpacing.l, AppSpacing.xs, AppSpacing.s),
                    child: Text('Aane Wale Modules',
                        style: AppTypography.labelLarge(context)
                            .copyWith(color: Colors.grey)),
                  ),
                  ..._upcoming.map((item) => Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.medium,
                          side: BorderSide(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.1)),
                        ),
                        child: ListTile(
                          leading: Icon(item.icon, color: Colors.grey),
                          title: Text(item.title,
                              style: const TextStyle(color: Colors.grey)),
                          trailing: Text(item.phaseNote,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
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
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
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
