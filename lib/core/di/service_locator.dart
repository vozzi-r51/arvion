import 'package:get_it/get_it.dart';
import '../database/db_helper.dart';
import '../events/domain_event_bus.dart';
import '../repositories/sales_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/cost_center_repository.dart';
import '../repositories/accounting_repository.dart';
import '../repositories/hr_repository.dart';
import '../repositories/fixed_assets_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/currency_repository.dart';
import '../repositories/fiscal_year_repository.dart';
import '../repositories/data_archive_repository.dart';
import '../listeners/accounting_event_listener.dart';
import '../listeners/ledger_event_listener.dart';
import '../listeners/inventory_alert_listener.dart';
import '../services/sales_service.dart';
import '../services/purchase_service.dart';
import '../services/customer_service.dart';
import '../services/inventory_service.dart';
import '../services/expense_service.dart';

/// The global service locator. Use `sl<SalesRepository>()` from anywhere
/// instead of `SalesRepository()` so tests can swap implementations.
///
/// Wiring order matters: DBHelper must be initialized first, then
/// repositories (which need the DB), then event listeners (which need
/// both the bus and the audit logger).
final GetIt sl = GetIt.instance;

/// One-shot init. Call from `main()` before `runApp`.
Future<void> setupServiceLocator() async {
  // DB — the singleton we already use everywhere. Register the *instance*
  // so `sl<DBHelper>()` returns the same object every time.
  if (!sl.isRegistered<DBHelper>()) {
    sl.registerSingleton<DBHelper>(DBHelper.instance);
    // Force DB open so repositories can rely on it.
    await DBHelper.instance.database;
  }

  // Event bus — also a singleton.
  if (!sl.isRegistered<DomainEventBus>()) {
    sl.registerSingleton<DomainEventBus>(DomainEventBus.instance);
  }

  // Repositories — lazy singletons. They hold no state besides the
  // shared Database handle, so a single instance is fine.
  if (!sl.isRegistered<SalesRepository>()) {
    sl.registerLazySingleton<SalesRepository>(() => SalesRepository());
  }
  if (!sl.isRegistered<InventoryRepository>()) {
    sl.registerLazySingleton<InventoryRepository>(() => InventoryRepository());
  }
  if (!sl.isRegistered<PurchaseRepository>()) {
    sl.registerLazySingleton<PurchaseRepository>(() => PurchaseRepository());
  }
  if (!sl.isRegistered<CustomerRepository>()) {
    sl.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
  }
  if (!sl.isRegistered<SupplierRepository>()) {
    sl.registerLazySingleton<SupplierRepository>(() => SupplierRepository());
  }
  if (!sl.isRegistered<ExpenseRepository>()) {
    sl.registerLazySingleton<ExpenseRepository>(() => ExpenseRepository());
  }
  if (!sl.isRegistered<AnalyticsRepository>()) {
    sl.registerLazySingleton<AnalyticsRepository>(() => AnalyticsRepository());
  }
  if (!sl.isRegistered<CostCenterRepository>()) {
    sl.registerLazySingleton<CostCenterRepository>(() => CostCenterRepository());
  }
  if (!sl.isRegistered<AccountingRepository>()) {
    sl.registerLazySingleton<AccountingRepository>(() => AccountingRepository());
  }
  if (!sl.isRegistered<HrRepository>()) {
    sl.registerLazySingleton<HrRepository>(() => HrRepository());
  }
  if (!sl.isRegistered<FixedAssetsRepository>()) {
    sl.registerLazySingleton<FixedAssetsRepository>(() => FixedAssetsRepository());
  }
  if (!sl.isRegistered<BudgetRepository>()) {
    sl.registerLazySingleton<BudgetRepository>(() => BudgetRepository());
  }
  if (!sl.isRegistered<CurrencyRepository>()) {
    sl.registerLazySingleton<CurrencyRepository>(() => CurrencyRepository());
  }
  if (!sl.isRegistered<FiscalYearRepository>()) {
    sl.registerLazySingleton<FiscalYearRepository>(() => FiscalYearRepository());
  }
  if (!sl.isRegistered<DataArchiveRepository>()) {
    sl.registerLazySingleton<DataArchiveRepository>(() => DataArchiveRepository());
  }

  // Services (built on repositories, handle multi-repo coordination)
  if (!sl.isRegistered<SalesService>()) {
    sl.registerLazySingleton<SalesService>(() => SalesService(
      salesRepository: sl<SalesRepository>(),
      inventoryRepository: sl<InventoryRepository>(),
      customerRepository: sl<CustomerRepository>(),
    ));
  }
  if (!sl.isRegistered<PurchaseService>()) {
    sl.registerLazySingleton<PurchaseService>(() => PurchaseService(
      purchaseRepository: sl<PurchaseRepository>(),
      inventoryRepository: sl<InventoryRepository>(),
      supplierRepository: sl<SupplierRepository>(),
    ));
  }
  if (!sl.isRegistered<CustomerService>()) {
    sl.registerLazySingleton<CustomerService>(() => CustomerService(
      customerRepository: sl<CustomerRepository>(),
    ));
  }
  if (!sl.isRegistered<InventoryService>()) {
    sl.registerLazySingleton<InventoryService>(() => InventoryService(
      inventoryRepository: sl<InventoryRepository>(),
    ));
  }
  if (!sl.isRegistered<ExpenseService>()) {
    sl.registerLazySingleton<ExpenseService>(() => ExpenseService(
      expenseRepository: sl<ExpenseRepository>(),
    ));
  }

  // Wire event listeners. Register them once at startup so that any
  // module that emits events triggers the reactions.
  if (!sl.isRegistered<AccountingEventListener>()) {
    final listener = AccountingEventListener();
    listener.register();
    sl.registerSingleton<AccountingEventListener>(listener);
  }
  if (!sl.isRegistered<LedgerEventListener>()) {
    final listener = LedgerEventListener();
    listener.register();
    sl.registerSingleton<LedgerEventListener>(listener);
  }
  if (!sl.isRegistered<InventoryAlertListener>()) {
    final listener = InventoryAlertListener();
    listener.register();
    sl.registerSingleton<InventoryAlertListener>(listener);
  }
}
