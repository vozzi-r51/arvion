# 🎬 Screen Migration Guide — Phase 4 Wave 1

## Pattern: Replace DBHelper → Use Service via DI

### Template

**Before:**
```dart
import '../../core/database/db_helper.dart';

final result = await DBHelper.instance.someMethod(params);
```

**After:**
```dart
import '../../core/di/service_locator.dart';
import '../../core/services/sales_service.dart';

final result = await sl<SalesService>().someMethod(params);
```

---

## Screen 1: `lib/features/sales/new_sale_screen.dart`

### Changes Required

| Line | Current | Change To |
|------|---------|-----------|
| Top | `import '../../core/database/db_helper.dart';` | `import '../../core/di/service_locator.dart';` + `import '../../core/services/sales_service.dart';` |
| 470 | `await DBHelper.instance.insertSaleWithItems(...)` | `await sl<SalesService>().createSaleWithItems(...)` |
| 62 | `await DBHelper.instance.getTodaysSalesTotal(...)` | `await sl<SalesService>().getTodaysSalesTotal(...)` |
| **Keep as-is** | `DBHelper.instance.getCustomers()` | Still use DBHelper (needs CustomerService or direct call) |
| **Keep as-is** | `DBHelper.instance.generateInvoiceNumber()` | Still use DBHelper (utility, not high priority) |

**Impact:** ✅ Sale creation now goes through service → event bus → listeners → audit log automatic

---

## Screen 2: `lib/features/purchases/new_purchase_screen.dart`

### Changes Required

| Line | Current | Change To |
|------|---------|-----------|
| Top | `import '../../core/database/db_helper.dart';` | `import '../../core/di/service_locator.dart';` + `import '../../core/services/purchase_service.dart';` |
| ~similar to sales | `await DBHelper.instance.insertPurchaseWithItems(...)` | `await sl<PurchaseService>().createPurchaseWithItems(...)` |
| ~similar | `await DBHelper.instance.getTodaysPurchaseTotal(...)` | `await sl<PurchaseService>().getTodaysPurchaseTotal(...)` |

**Impact:** ✅ Purchase creation now emits events → ledger listener posts journal entries automatically

---

## Screen 3: `lib/features/customers/customer_list_screen.dart` (or customer form)

### Changes Required

| Line | Current | Change To |
|------|---------|-----------|
| Top | `import '../../core/database/db_helper.dart';` | `import '../../core/di/service_locator.dart';` + `import '../../core/services/customer_service.dart';` |
| Create | `await DBHelper.instance.insertCustomer(...)` | `await sl<CustomerService>().createCustomer(...)` |
| List | `await DBHelper.instance.getCustomers(...)` | `await sl<CustomerService>().listCustomers(...)` |
| Count | `await DBHelper.instance.getCustomerCount(...)` | `await sl<CustomerService>().getCustomerCount(...)` |
| Payment | `await DBHelper.instance.recordPayment(...)` | `await sl<CustomerService>().recordPayment(...)` |

**Impact:** ✅ Customer creation emits events → customers appear in analytics automatically

---

## Checklist for Each Screen

- [ ] Add DI + service imports
- [ ] Replace DBHelper calls with `sl<Service>()`  calls
- [ ] Keep utility calls on DBHelper (getProducts, generateInvoiceNumber, etc.) — not critical path
- [ ] Run `flutter analyze` — should be 0 errors
- [ ] Test the screen — sale/purchase/customer creation should still work
- [ ] Verify event listeners fire (check console logs for "⚠️  LOW STOCK ALERT" etc.)

---

## Why This Works

1. **Service layer** handles coordination (stock + AR + events)
2. **Repositories** own single domains (sales, inventory, customers)
3. **Event bus** triggers listeners (audit, ledger, alerts)
4. **Screens are decoupled** — just call the service, don't worry about side-effects

Example: Create a sale
```
Screen calls: sl<SalesService>().createSaleWithItems(...)
  ↓
Service calls: DBHelper.insertSaleWithItems(...) [legacy, handles stock + AR]
  ↓
Service emits: SaleCompletedEvent
  ↓
Listeners fire:
  - AccountingEventListener → logs audit entry
  - LedgerEventListener → posts journal entries (TODO)
  - InventoryAlertListener → checks low-stock (logs/notification)
```

---

## Next Waves (After Wave 1 Verified)

### Wave 2: More Screens
- Sales return screens
- Purchase return screens
- Expense recording
- Payment screens (receive/pay)

### Wave 3: Refactor Complex Methods
Once comfortable, move `insertSaleWithItems` logic out of DBHelper into SalesService:
- Stock deduction → call InventoryRepository
- AR update → call CustomerRepository
- Event → already handled
- No DBHelper dependency anymore

---

## Testing: Fake Services

Once all 3 screens are migrated, tests become trivial:

```dart
// test_setup.dart
sl.registerSingleton<SalesService>(FakeSalesService());
sl.registerSingleton<PurchaseService>(FakePurchaseService());
sl.registerSingleton<CustomerService>(FakeCustomerService());

// Now run sales/purchase/customer screens — zero DB needed, super fast
```

---

**Status:** Pattern proven with Dashboard. Now apply to Sales → Purchases → Customers.
