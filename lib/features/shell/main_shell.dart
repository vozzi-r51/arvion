import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../dashboard/dashboard_screen.dart';
import '../products/products_home_screen.dart';
import '../sales/sales_home_screen.dart';
import '../purchases/purchases_home_screen.dart';
import '../customers/customer_list_screen.dart';
import '../customers/supplier_list_screen.dart';
import '../finance/expense_list_screen.dart';
import '../journal/journal_home_screen.dart';
import '../reports/reports_home_screen.dart';
import '../settings/settings_screen.dart';
import '../ai/ai_screen.dart';
import '../../core/widgets/arvion_logo.dart';
import '../../core/backup/backup_service.dart';
import '../../core/auth/session.dart';
import '../../core/notifications/notification_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Static helper to open the drawer from any screen hosted inside MainShell
  static void openDrawer(BuildContext context) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?._scaffoldKey.currentState?.openDrawer();
  }

  /// Helper to get a menu button for AppBars of screens inside the shell.
  /// Returns null on desktop where the sidebar is permanent.
  static Widget? getMenuButton(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) return null;
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () => openDrawer(context),
    );
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  int? _companyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final company = await DBHelper.instance.getActiveCompany();
    setState(() {
      _companyId = company?['id'] as int?;
      _loading = false;
    });
    BackupService.maybeRunAutoBackup();
    if (company != null) {
      NotificationService.maybeNotify(company['id'] as int);
    }
  }

  void _onItemSelected(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner = Session.isOwner;

    // Define all possible navigation items
    final List<_NavItemData> navItems = [
      _NavItemData('Dashboard', Icons.dashboard, Icons.dashboard_outlined),
      _NavItemData('Sales', Icons.point_of_sale, Icons.point_of_sale_outlined),
      _NavItemData('Purchases', Icons.shopping_cart, Icons.shopping_cart_outlined),
      _NavItemData('Customers', Icons.people, Icons.people_outline),
      _NavItemData('Vendors / Suppliers', Icons.business, Icons.business_outlined),
      _NavItemData('Inventory', Icons.inventory_2, Icons.inventory_2_outlined, isOwnerOnly: true),
      _NavItemData('Expenses', Icons.payments, Icons.payments_outlined, isOwnerOnly: true),
      _NavItemData('Accounting', Icons.account_balance, Icons.account_balance_outlined, isOwnerOnly: true),
      _NavItemData('Reports', Icons.bar_chart, Icons.bar_chart_outlined, isOwnerOnly: true),
      _NavItemData('AI Assistant', Icons.auto_awesome, Icons.auto_awesome_outlined),
      _NavItemData('Settings', Icons.settings, Icons.settings_outlined),
    ];

    // Filter items based on permissions
    final visibleNavItems = navItems.where((item) => !item.isOwnerOnly || isOwner).toList();

    // Ensure _index is within bounds after filtering (though items are usually static)
    if (_index >= visibleNavItems.length) _index = 0;

    // Map visible items to their screens
    final List<Widget> pages = visibleNavItems.map((item) {
      switch (item.title) {
        case 'Dashboard': return const DashboardScreen();
        case 'Sales': return SalesHomeScreen(companyId: _companyId!);
        case 'Purchases': return PurchasesHomeScreen(companyId: _companyId!);
        case 'Customers': return CustomerListScreen(companyId: _companyId!);
        case 'Vendors / Suppliers': return SupplierListScreen(companyId: _companyId!);
        case 'Inventory': return ProductsHomeScreen(companyId: _companyId!);
        case 'Expenses': return ExpenseListScreen(companyId: _companyId!);
        case 'Accounting': return JournalHomeScreen(companyId: _companyId!);
        case 'Reports': return ReportsHomeScreen(companyId: _companyId!);
        case 'AI Assistant': return AIScreen(companyId: _companyId!);
        case 'Settings': return const SettingsScreen();
        default: return const Center(child: Text('Screen not found'));
      }
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint for persistent sidebar (Desktop/Tablet landscape).
        // Standard iPad landscape is 1024, iPad portrait is 768.
        // We use 900px to allow professional layout on most tablets.
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isDesktop ? null : Drawer(
            child: _buildSidebar(visibleNavItems, isDesktop: false),
          ),
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(visibleNavItems, isDesktop: true),
              if (isDesktop) const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: pages,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(List<_NavItemData> items, {required bool isDesktop}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: isDesktop ? 260 : null,
      color: isDesktop 
          ? (isDark ? const Color(0xFF0B1220) : Colors.white)
          : null,
      child: Column(
        children: [
          _buildSidebarHeader(isDesktop),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _index == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white : Colors.black87),
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      _onItemSelected(index);
                      if (!isDesktop) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          if (isDesktop) _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.only(
        top: isDesktop ? 40 : 20,
        bottom: 20,
        left: 24,
        right: 20,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const ArvionLogo(size: 32),
          const SizedBox(width: 12),
          const Text(
            'ARVION',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.centerLeft,
      child: const Text(
        'v1.0.0',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

class _NavItemData {
  final String title;
  final IconData selectedIcon;
  final IconData icon;
  final bool isOwnerOnly;

  _NavItemData(this.title, this.selectedIcon, this.icon, {this.isOwnerOnly = false});
}
