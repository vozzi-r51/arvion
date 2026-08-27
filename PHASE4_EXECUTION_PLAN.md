# 🎬 Phase 4 Screen Migration — Execution Plan

## Status: Ready to Migrate

**3 Screens:** Sales | Purchases | Customers  
**Pattern:** Replace DBHelper → Use Service via DI  
**Risk Level:** Low (Services wrap legacy code, no behavior change)

---

## Screen 1: `lib/features/sales/new_sale_screen.dart`

### Current DBHelper Calls (9 total)

| Line ~| Current | Replace With | Priority |
|------|---------|--------------|----------|
| 112 | `DBHelper.instance.getActivePromotions()` | Keep as-is | Low |
| 118 | `DBHelper.instance.getCustomers()` | Keep as-is | Low |
| 119 | `DBHelper.instance.getCompanyById()` | Keep as-is | Low |
| 198 | `DBHelper.instance.getRestaurantTables()` | Keep as-is | Low |
| 274 | `DBHelper.instance.getProductVariants()` | Keep as-is | Low |
| 428 | `DBHelper.instance.generateInvoiceNumber()` | Keep as-is | Low |
| 470 | `DBHelper.instance.insertSaleWithItems()` | ✅ `sl<SalesService>().createSaleWithItems()` | **HIGH** |
| 499 | `DBHelper.instance.getCompanyById()` | Keep as-is | Low |
| 923 | `DBHelper.instance.getProducts()` | Keep as-is | Low |

### Changes Required

**Step 1: Update imports (top of file)**
```dart
- import '../../core/database/db_helper.dart';
+ import '../../core/di/service_locator.dart';
+ import '../../core/services/sales_service.dart';
```

**Step 2: Find & Replace line ~470**
```dart
- saleId = await DBHelper.instance.insertSaleWithItems(
-   sale: sale,
-   items: saleItems,
-   allowNegativeStock: allowNegativeStock,
- );

+ saleId = await sl<SalesService>().createSaleWithItems(
+   sale: sale,
+   items: saleItems,
+   allowNegativeStock: allowNegativeStock,
+ );
```

**Result:** Sale creation now goes through service → emits event → listeners fire

---

## Screen 2: `lib/features/purchases/new_purchase_screen.dart`

### Current DBHelper Calls (similar pattern)

| Line ~| Current | Replace With | Priority |
|------|---------|--------------|----------|
| ~similar | `DBHelper.instance.insertPurchaseWithItems()` | ✅ `sl<PurchaseService>().createPurchaseWithItems()` | **HIGH** |
| ~similar | `DBHelper.instance.generateInvoiceNumber()` | Keep as-is | Low |
| ~similar | Other utility calls | Keep as-is | Low |

### Changes Required

**Step 1: Update imports**
```dart
- import '../../core/database/db_helper.dart';
+ import '../../core/di/service_locator.dart';
+ import '../../core/services/purchase_service.dart';
```

**Step 2: Replace purchase creation**
```dart
- purchaseId = await DBHelper.instance.insertPurchaseWithItems(...);

+ purchaseId = await sl<PurchaseService>().createPurchaseWithItems(...);
```

---

## Screen 3: `lib/features/customers/customer_list_screen.dart` (or form)

### Current DBHelper Calls

| Line ~| Current | Replace With | Priority |
|------|---------|--------------|----------|
| ~create | `DBHelper.instance.insertCustomer()` | ✅ `sl<CustomerService>().createCustomer()` | **HIGH** |
| ~list | `DBHelper.instance.getCustomers()` | ✅ `sl<CustomerService>().listCustomers()` | **HIGH** |
| ~count | `DBHelper.instance.getCustomerCount()` | ✅ `sl<CustomerService>().getCustomerCount()` | **HIGH** |
| ~update | `DBHelper.instance.updateCustomer()` | ✅ `sl<CustomerService>().updateCustomer()` | **HIGH** |
| ~delete | `DBHelper.instance.deleteCustomer()` | ✅ `sl<CustomerService>().deleteCustomer()` | **HIGH** |

### Changes Required

**Step 1: Update imports**
```dart
- import '../../core/database/db_helper.dart';
+ import '../../core/di/service_locator.dart';
+ import '../../core/services/customer_service.dart';
```

**Step 2: Replace all CRUD calls**
```dart
- final customers = await DBHelper.instance.getCustomers(companyId);
+ final customers = await sl<CustomerService>().listCustomers(companyId);

- final count = await DBHelper.instance.getCustomerCount(companyId);
+ final count = await sl<CustomerService>().getCustomerCount(companyId);

- await DBHelper.instance.insertCustomer(customerData);
+ await sl<CustomerService>().createCustomer(customerData);

- await DBHelper.instance.updateCustomer(id, data);
+ await sl<CustomerService>().updateCustomer(id, data);

- await DBHelper.instance.deleteCustomer(id);
+ await sl<CustomerService>().deleteCustomer(id);
```

---

## Checklist for Each Screen

- [ ] **Step 1:** Add DI + service imports
- [ ] **Step 2:** Find all DBHelper calls (use Find & Replace)
- [ ] **Step 3:** Replace HIGH priority calls with service calls
- [ ] **Step 4:** Run `flutter analyze` — should see 0 errors
- [ ] **Step 5:** Test on device — create sale/purchase/customer should work
- [ ] **Step 6:** Verify events fire (check console for audit logs)

---

## Order of Migration

1. **Sales Screen** first (most complex, highest impact)
2. **Purchases Screen** second (similar pattern, learn from sales)
3. **Customers Screen** third (simpler, lowest risk)

---

## Verification After Each Screen

```bash
# After each screen, run:
flutter analyze lib/features/sales/new_sale_screen.dart
flutter analyze lib/features/purchases/new_purchase_screen.dart
flutter analyze lib/features/customers/customer_list_screen.dart

# Should see: ✅ 0 errors

# Then test:
flutter run
# Create a sale → event should fire → audit log should appear
```

---

## Expected Results After Phase 4 Complete

✅ 3 screens migrated to DI + services  
✅ Sales/purchases/customer creation → auto-audit logs  
✅ Events flowing through bus → listeners reacting  
✅ Dashboard already migrated (proven pattern)  
✅ Foundation solid for Phase 5b (UI + reports)

---

## Rollback Plan (If Issues)

Each screen change is isolated. If a screen breaks:
1. Revert the imports + service calls
2. Back to `DBHelper.instance` calls
3. No other screens affected

---

**Ready to execute. Start with Sales Screen?**
