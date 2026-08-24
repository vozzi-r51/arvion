import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/theme/arvion_brand.dart';
import '../settings/settings_screen.dart';
import '../products/product_form_screen.dart';
import '../customers/customer_form_screen.dart';
import '../sales/new_sale_screen.dart';
import '../purchases/new_purchase_screen.dart';
import '../../core/auth/session.dart';
import '../search/global_search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _DashboardStat(this.title, this.value, this.icon, this.color);
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String comingInPhase;
  const _QuickAction(this.label, this.icon, this.comingInPhase);
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _activeCompany;
  int _productCount = 0;
  int _lowStockCount = 0;
  int _customerCount = 0;
  int _supplierCount = 0;
  double _todaysSales = 0;
  double _todaysProfit = 0;
  double _todaysPurchase = 0;
  double _todaysExpenses = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final company = await DBHelper.instance.getActiveCompany();
    if (company != null) {
      final companyId = company['id'] as int;
      final productCount = await DBHelper.instance.getProductCount(companyId);
      final lowStockCount = await DBHelper.instance.getLowStockCount(companyId);
      final customerCount = await DBHelper.instance.getCustomerCount(companyId);
      final supplierCount = await DBHelper.instance.getSupplierCount(companyId);
      final todaysSales = await DBHelper.instance.getTodaysSalesTotal(companyId);
      final todaysProfit = await DBHelper.instance.getTodaysProfit(companyId);
      final todaysPurchase =
          await DBHelper.instance.getTodaysPurchaseTotal(companyId);
      final todaysExpenses =
          await DBHelper.instance.getTodaysExpensesTotal(companyId);
      setState(() {
        _activeCompany = company;
        _productCount = productCount;
        _lowStockCount = lowStockCount;
        _customerCount = customerCount;
        _supplierCount = supplierCount;
        _todaysSales = todaysSales;
        _todaysProfit = todaysProfit;
        _todaysPurchase = todaysPurchase;
        _todaysExpenses = todaysExpenses;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  // Everything on this dashboard is now live (Phase 3 through 7).
  List<_DashboardStat> get _stats => [
        _DashboardStat('Today\'s Sales', 'Rs. ${_todaysSales.toStringAsFixed(0)}',
            Icons.point_of_sale, Colors.teal),
        _DashboardStat('Today\'s Purchase', 'Rs. ${_todaysPurchase.toStringAsFixed(0)}',
            Icons.shopping_cart, Colors.indigo),
        _DashboardStat('Today\'s Profit', 'Rs. ${_todaysProfit.toStringAsFixed(0)}',
            Icons.trending_up, Colors.green),
        _DashboardStat('Today\'s Expenses', 'Rs. ${_todaysExpenses.toStringAsFixed(0)}',
            Icons.receipt_long, Colors.orange),
        _DashboardStat('Total Customers', '$_customerCount', Icons.people,
            Colors.blue),
        _DashboardStat('Total Suppliers', '$_supplierCount',
            Icons.local_shipping, Colors.purple),
        _DashboardStat('Total Products', '$_productCount', Icons.inventory_2,
            Colors.brown),
        _DashboardStat('Low Stock Alert', '$_lowStockCount',
            Icons.warning_amber, Colors.red),
      ];

  final List<_QuickAction> _quickActions = const [
    _QuickAction('Add Product', Icons.add_box_outlined, 'Phase 3'),
    _QuickAction('New Customer', Icons.person_add_alt, 'Phase 4'),
    _QuickAction('New Sale', Icons.point_of_sale_outlined, 'Phase 5'),
    _QuickAction('New Purchase', Icons.shopping_bag_outlined, 'Phase 6'),
  ];

  void _showComingSoon(String phase) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ye feature $phase mein activate hoga')),
    );
  }

  Future<void> _handleQuickAction(_QuickAction action) async {
    if (_activeCompany == null) return;
    final companyId = _activeCompany!['id'] as int;

    if (action.label == 'Add Product') {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(companyId: companyId),
        ),
      );
      if (result == true) _loadAll();
      return;
    }

    if (action.label == 'New Customer') {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerFormScreen(companyId: companyId),
        ),
      );
      if (result == true) _loadAll();
      return;
    }

    if (action.label == 'New Sale') {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewSaleScreen(companyId: companyId),
        ),
      );
      if (result == true) _loadAll();
      return;
    }

    if (action.label == 'New Purchase') {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewPurchaseScreen(companyId: companyId),
        ),
      );
      if (result == true) _loadAll();
      return;
    }

    _showComingSoon(action.comingInPhase);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ARVION',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          Theme.of(context).colorScheme.primary.withOpacity(0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business_outlined, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _activeCompany?['name'] as String? ?? 'Your Company',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Search',
                          icon: const Icon(Icons.search),
                          onPressed: _activeCompany == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GlobalSearchScreen(
                                        companyId: _activeCompany!['id'] as int,
                                      ),
                                    ),
                                  ),
                        ),
                        if (Session.isOwner)
                          IconButton(
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()))
                                .then((_) => _loadAll()),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Smart Business. Simple Control.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickActions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final action = _quickActions[i];
                        return GestureDetector(
                          onTap: () => _handleQuickAction(action),
                          child: Container(
                            width: 96,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.12),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    action.icon,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  action.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stats.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.45,
                    ),
                    itemBuilder: (ctx, i) {
                      final stat = _stats[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: stat.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(stat.icon, color: stat.color, size: 18),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              stat.value,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stat.title,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }
}
