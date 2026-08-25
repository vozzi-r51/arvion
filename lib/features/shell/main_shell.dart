import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../dashboard/dashboard_screen.dart';
import '../products/products_home_screen.dart';
import '../sales/sales_home_screen.dart';
import '../more/more_menu_screen.dart';
import '../../core/backup/backup_service.dart';
import '../../core/auth/session.dart';
import '../../core/notifications/notification_service.dart';
import '../ai/ai_screen.dart';

/// Root screen shown after a company is selected. Holds the bottom
/// navigation between Dashboard, Sales, Products, More and AI.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
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
    // Best-effort silent auto-backup check (no-op if run recently/disabled).
    BackupService.maybeRunAutoBackup();
    if (company != null) {
      NotificationService.maybeNotify(company['id'] as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner = Session.isOwner;

    final pages = [
      const DashboardScreen(),
      SalesHomeScreen(companyId: _companyId!),
      if (isOwner) ProductsHomeScreen(companyId: _companyId!),
      if (isOwner) MoreMenuScreen(companyId: _companyId!),
      AIScreen(companyId: _companyId!),
    ];

    final destinations = [
      const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home'),
      const NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: 'Sales'),
      if (isOwner)
        const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock'),
      if (isOwner)
        const NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More'),
      const NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'AI'),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
