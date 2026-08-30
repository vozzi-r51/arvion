import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/db_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/customer_repository.dart';
import '../../core/repositories/supplier_repository.dart';
import '../../core/repositories/sales_repository.dart';
import '../../core/repositories/purchase_repository.dart';
import '../../core/repositories/expense_repository.dart';
import '../../core/repositories/analytics_repository.dart';
import '../../core/services/query_cache_service.dart';
import '../../core/services/error_reporter.dart';
import '../../core/providers/localization_provider.dart';
import '../settings/settings_screen.dart';
import '../products/product_form_screen.dart';
import '../customers/customer_form_screen.dart';
import '../sales/new_sale_screen.dart';
import '../purchases/new_purchase_screen.dart';
import '../purchase_order/new_purchase_order_screen.dart';
import '../finance/expense_list_screen.dart';
import '../sales/sales_home_screen.dart';
import '../customers/customer_list_screen.dart';
import '../customers/supplier_list_screen.dart';
import '../products/category_list_screen.dart';
import '../reports/profit_report_screen.dart';
import '../../core/auth/session.dart';
import '../search/global_search_screen.dart';
import '../shell/main_shell.dart';
import '../../core/widgets/bizmanager_logo.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/providers/terminology_provider.dart';
import '../../l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _activeCompany;
  int _productCount = 0;
  int _lowStockCount = 0;
  List<Map<String, dynamic>> _lowStockProducts = [];
  int _customerCount = 0;
  int _supplierCount = 0;
  double _todaysSales = 0;
  double _todaysProfit = 0;
  double _todaysPurchase = 0;
  double _todaysExpenses = 0;
  List<FlSpot> _salesSpots = [];
  List<FlSpot> _purchaseSpots = [];
  List<BarChartGroupData> _topProductGroups = [];
  String _currency = 'Rs.';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final company = await DBHelper.instance.getActiveCompany();
      if (company != null) {
        final companyId = company['id'] as int;
        final cacheKey = 'dashboard_stats_$companyId';

        if (forceRefresh) {
          QueryCacheService.instance.invalidate(cacheKey);
        }

        final cached =
            QueryCacheService.instance.get<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          _todaysSales = (cached['todaysSales'] as num?)?.toDouble() ?? 0.0;
          _todaysProfit = (cached['todaysProfit'] as num?)?.toDouble() ?? 0.0;
          _todaysPurchase =
              (cached['todaysPurchase'] as num?)?.toDouble() ?? 0.0;
          _todaysExpenses =
              (cached['todaysExpenses'] as num?)?.toDouble() ?? 0.0;
          _currency = (cached['currency'] as String?) ?? 'Rs.';
          _loading = false;
          if (mounted) setState(() {});
          return;
        }

        // Use repositories with safe fallback
        final inventoryRepo = sl.isRegistered<InventoryRepository>()
            ? sl<InventoryRepository>()
            : null;
        final customerRepo = sl.isRegistered<CustomerRepository>()
            ? sl<CustomerRepository>()
            : null;
        final supplierRepo = sl.isRegistered<SupplierRepository>()
            ? sl<SupplierRepository>()
            : null;
        final salesRepo =
            sl.isRegistered<SalesRepository>() ? sl<SalesRepository>() : null;
        final purchaseRepo = sl.isRegistered<PurchaseRepository>()
            ? sl<PurchaseRepository>()
            : null;
        final expenseRepo = sl.isRegistered<ExpenseRepository>()
            ? sl<ExpenseRepository>()
            : null;
        final analyticsRepo = sl.isRegistered<AnalyticsRepository>()
            ? sl<AnalyticsRepository>()
            : null;

        final productCount = inventoryRepo != null
            ? await inventoryRepo.getProductCount(companyId)
            : 0;
        final lowStockCount = inventoryRepo != null
            ? await inventoryRepo.getLowStockCount(companyId)
            : 0;
        final customerCount = customerRepo != null
            ? await customerRepo.getCustomerCount(companyId)
            : 0;
        final supplierCount = supplierRepo != null
            ? await supplierRepo.getSupplierCount(companyId)
            : 0;

        _todaysSales = salesRepo != null
            ? await salesRepo.getTodaysSalesTotal(companyId)
            : 0.0;
        _todaysProfit = analyticsRepo != null
            ? await analyticsRepo.getTodaysProfit(companyId)
            : 0.0;
        _todaysPurchase = purchaseRepo != null
            ? await purchaseRepo.getTodaysPurchaseTotal(companyId)
            : 0.0;
        _todaysExpenses = expenseRepo != null
            ? await expenseRepo.getTodaysExpensesTotal(companyId)
            : 0.0;

        _currency = (company['currency_symbol'] as String?) ?? 'Rs.';

        final lowStockProducts =
            await DBHelper.instance.getLowStockProducts(companyId);

        final to = DateTime.now();
        final from = to.subtract(const Duration(days: 30));
        final sales = await DBHelper.instance.getSalesBetween(
            companyId,
            from.toIso8601String().substring(0, 10),
            to.toIso8601String().substring(0, 10));
        final purchases = await DBHelper.instance.getPurchasesBetween(
            companyId,
            from.toIso8601String().substring(0, 10),
            to.toIso8601String().substring(0, 10));

        final Map<int, double> salesMap = {};
        final Map<int, double> purchaseMap = {};

        for (var s in sales) {
          final rawDate = s['sale_date'] as String?;
          final parsedDate =
              rawDate != null ? DateTime.tryParse(rawDate) : null;
          final day = parsedDate?.day ?? DateTime.now().day;
          final amount = (s['total_amount'] as num?)?.toDouble() ??
              (s['total'] as num?)?.toDouble() ??
              0.0;
          salesMap[day] = (salesMap[day] ?? 0.0) + amount;
        }

        for (var p in purchases) {
          final rawDate = p['purchase_date'] as String?;
          final parsedDate =
              rawDate != null ? DateTime.tryParse(rawDate) : null;
          final day = parsedDate?.day ?? DateTime.now().day;
          final amount = (p['total_amount'] as num?)?.toDouble() ??
              (p['total'] as num?)?.toDouble() ??
              0.0;
          purchaseMap[day] = (purchaseMap[day] ?? 0.0) + amount;
        }

        QueryCacheService.instance.set(
            cacheKey,
            {
              'productCount': productCount,
              'lowStockCount': lowStockCount,
              'customerCount': customerCount,
              'supplierCount': supplierCount,
              'todaysSales': _todaysSales,
              'todaysProfit': _todaysProfit,
              'todaysPurchase': _todaysPurchase,
              'todaysExpenses': _todaysExpenses,
              'currency': _currency,
              'lowStockProducts': lowStockProducts,
              'salesMap': salesMap,
              'purchaseMap': purchaseMap,
            },
            ttl: const Duration(minutes: 5));

        final List<FlSpot> sSpots = [];
        final List<FlSpot> pSpots = [];
        for (int i = 0; i < 30; i++) {
          final date = from.add(Duration(days: i));
          final day = date.day;
          sSpots.add(FlSpot(i.toDouble(), salesMap[day] ?? 0.0));
          pSpots.add(FlSpot(i.toDouble(), purchaseMap[day] ?? 0.0));
        }

        // Top Products
        final topProds =
            await DBHelper.instance.getTopSellingProducts(companyId);
        final List<BarChartGroupData> groups = [];
        for (int i = 0; i < topProds.length; i++) {
          final qty = (topProds[i]['total_qty'] as num?)?.toDouble() ??
              (topProds[i]['quantity'] as num?)?.toDouble() ??
              0.0;
          groups.add(BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: qty,
                color: Colors.blueAccent,
                width: 15,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          ));
        }

        if (mounted) {
          setState(() {
            _activeCompany = company;
            _productCount = productCount;
            _lowStockCount = lowStockCount;
            _lowStockProducts = lowStockProducts;
            _customerCount = customerCount;
            _supplierCount = supplierCount;
            _salesSpots = sSpots;
            _purchaseSpots = pSpots;
            _topProductGroups = groups;
          });
        }
      }
    } catch (e, s) {
      ErrorReporter.instance.report(e,
          module: 'Dashboard', action: 'loadAll', stack: s.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Filtered based on role
  List<_DashboardStat> get _stats {
    final isOwner = Session.isOwner;
    final term = context.read<TerminologyProvider>();
    final locProvider = context.read<LocalizationProvider>();

    return [
      _DashboardStat(
          'Today\'s ${term.get('sale')}s',
          locProvider.formatCurrency(_todaysSales),
          Icons.point_of_sale,
          Colors.teal),
      if (isOwner)
        _DashboardStat(
            'Today\'s Purchase',
            locProvider.formatCurrency(_todaysPurchase),
            Icons.shopping_cart,
            Colors.indigo),
      if (isOwner)
        _DashboardStat(
            'Today\'s Profit',
            locProvider.formatCurrency(_todaysProfit),
            Icons.trending_up,
            Colors.green),
      if (isOwner)
        _DashboardStat(
            'Today\'s Expenses',
            locProvider.formatCurrency(_todaysExpenses),
            Icons.receipt_long,
            Colors.orange),
      _DashboardStat(
          'Total Customers', '$_customerCount', Icons.people, Colors.blue),
      if (isOwner)
        _DashboardStat('Total Suppliers', '$_supplierCount',
            Icons.local_shipping, Colors.purple),
      _DashboardStat('Total ${term.get('product')}s', '$_productCount',
          Icons.inventory_2, Colors.brown),
      _DashboardStat('Low Stock Alert', '$_lowStockCount', Icons.warning_amber,
          Colors.red),
    ];
  }

  List<_QuickAction> get _quickActions {
    final term = context.read<TerminologyProvider>();
    return [
      _QuickAction(term.get('sale'), Icons.add_shopping_cart,
          color: Colors.teal),
      _QuickAction('Purchase', Icons.shopping_bag, color: Colors.indigo),
      _QuickAction('Expense', Icons.receipt_long, color: Colors.orange),
      _QuickAction(term.get('product'), Icons.add_box, color: Colors.brown),
      _QuickAction('Customer', Icons.person_add, color: Colors.blue),
    ];
  }

  void _handleQuickAction(_QuickAction action) {
    if (_activeCompany == null) return;
    final id = _activeCompany!['id'] as int;
    final term = context.read<TerminologyProvider>();

    if (action.title == term.get('sale')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => NewSaleScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }

    if (action.title == term.get('product')) {
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => ProductFormScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }

    switch (action.title) {
      case 'Purchase':
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => NewPurchaseScreen(companyId: id)))
            .then((_) => _loadAll());
        break;
      case 'Expense':
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => ExpenseListScreen(companyId: id)))
            .then((_) => _loadAll());
        break;
      case 'Customer':
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => CustomerFormScreen(companyId: id)))
            .then((_) => _loadAll());
        break;
    }
  }

  void _handleStatCardTap(_DashboardStat stat) {
    if (_activeCompany == null) return;
    final id = _activeCompany!['id'] as int;

    if (stat.title.contains('Sale')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SalesHomeScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }
    if (stat.title.contains('Expense')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ExpenseListScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }
    if (stat.title.contains('Profit')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ProfitReportScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }
    if (stat.title.contains('Customer')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CustomerListScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }
    if (stat.title.contains('Supplier')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SupplierListScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }
    if (stat.title.contains('Product') || stat.title.contains('Item')) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CategoryListScreen(companyId: id)))
          .then((_) => _loadAll());
      return;
    }
    if (stat.title.contains('Low Stock') || stat.title.contains('Alert')) {
      _showReorderSuggestions();
      return;
    }
  }

  void _showReorderSuggestions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Low Stock Suggestions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Text(
                'Niche diye gaye products apni limit se kam hain. Inhein reorder karne ka mashwara hai.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: _lowStockProducts.length,
                itemBuilder: (ctx, i) {
                  final p = _lowStockProducts[i];
                  final stock = (p['current_stock'] as num).toDouble();
                  final min = (p['min_stock_level'] as num).toDouble();
                  return ListTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: Text(p['name'] as String),
                    subtitle: Text('Stock: $stock | Min: $min'),
                    trailing: Text('Buy ${(min * 2 - stock).ceil()} more',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final initialItems = _lowStockProducts.map((p) {
                    final stock = (p['current_stock'] as num).toDouble();
                    final min = (p['min_stock_level'] as num).toDouble();
                    return {
                      'productId': p['id'] as int,
                      'name': p['name'] as String,
                      'unitCost': (p['purchase_price'] as num).toDouble(),
                      'qty': (min * 2 - stock).clamp(1.0, double.infinity),
                    };
                  }).toList();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewPurchaseOrderScreen(
                        companyId: _activeCompany!['id'] as int,
                        initialItems: initialItems,
                      ),
                    ),
                  );
                },
                child: const Text('Create PO'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.dashboard_title)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSkeleton.card(height: 180),
            const SizedBox(height: AppSpacing.l),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.m,
              crossAxisSpacing: AppSpacing.m,
              childAspectRatio: 1.6,
              children: List.generate(4, (index) => const AppSkeleton()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: Row(
          children: const [
            BizManagerLogo(size: 28),
            SizedBox(width: 10),
            Text(
              'BizManager',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAll(forceRefresh: true),
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
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
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
            _buildComingSoonBanner(),
            _buildSummaryCard(),
            const SizedBox(height: 18),
            if (_lowStockCount > 0) ...[
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading:
                      const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text('$_lowStockCount items low stock par hain'),
                  trailing: TextButton(
                    onPressed: _showReorderSuggestions,
                    child: const Text('Suggestions'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(action.icon,
                                color: action.color, size: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            action.title,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
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
              'Last 30 Days Trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            _buildChart(),
            const SizedBox(height: 20),
            Text(
              'Top 5 Products (by Qty)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            _buildBarChart(),
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
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (ctx, i) {
                final stat = _stats[i];
                return InkWell(
                  onTap: () => _handleStatCardTap(stat),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            Theme.of(context).dividerColor.withValues(alpha: 0.2),
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
                                color: stat.color.withValues(alpha: 0.12),
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
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final term = context.watch<TerminologyProvider>();
    return Card(
      elevation: AppElevation.low,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s ${term.get('sale')}s',
                      style: AppTypography.titleSmall(context)
                          .copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$_currency ${_todaysSales.toStringAsFixed(0)}',
                      style: AppTypography.headlineMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 24,
                  child: Icon(Icons.trending_up, color: Colors.white, size: 28),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: AppSpacing.l),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat(
                    'Profit', '$_currency ${_todaysProfit.toStringAsFixed(0)}'),
                _miniStat('Purchases',
                    '$_currency ${_todaysPurchase.toStringAsFixed(0)}'),
                _miniStat('Expenses',
                    '$_currency ${_todaysExpenses.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _salesSpots,
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true, color: Colors.teal.withValues(alpha: 0.1)),
            ),
            LineChartBarData(
              spots: _purchaseSpots,
              isCurved: true,
              color: Colors.indigo,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true, color: Colors.indigo.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_topProductGroups.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text('No sales data yet'),
      );
    }
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: _topProductGroups,
        ),
      ),
    );
  }

  Widget _buildComingSoonBanner() {
    final family = _activeCompany?['template_family'] as String?;
    if (family == null) return const SizedBox.shrink();

    final implementedFamilies = [
      'retailStandard',
      'retailVariant',
      'retailBatchExpiry',
      'serializedInventory',
      'retailCustomFields',
    ];

    if (implementedFamilies.contains(family)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: AppRadius.medium,
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coming Soon: ${family.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}').trim().toUpperCase()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.amber),
                ),
                const Text(
                  'Is business type ke liye makhsoos features aglay update mein shamil kiye jayenge. Filhal aap standard retail features use kar saktay hain.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _DashboardStat(this.title, this.value, this.icon, this.color);
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;

  _QuickAction(this.title, this.icon, {this.color = Colors.blue});
}
