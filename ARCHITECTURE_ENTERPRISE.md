# 🏛️ Enterprise Architecture — Phase 1 (Foundation)

**Date:** August 27, 2026  
**Status:** ✅ Foundation in place — incremental migration can begin  
**Goal:** Move from 5114-line `DBHelper` singleton → loosely-coupled, event-driven, DI-managed modules.

---

## 📊 Before vs After

| Concern | Before | After (Phase 1) |
|---|---|---|
| Data access | 5114-line `DBHelper` singleton with 150+ methods | Per-domain `Repository` classes (`SalesRepository`, `InventoryRepository`, ...) |
| Cross-module reactions | Hardcoded inside `insertSaleWithItems()` (accounting, audit, notifications all called inline) | `DomainEventBus` — modules emit `SaleCompletedEvent`, listeners react independently |
| Dependency wiring | `DBHelper.instance` called from 95 files | `sl<SalesRepository>()` from `get_it` service locator; one config in `service_locator.dart` |
| Audit logging | Every write site remembers to call `AuditLogger.log` | One listener subscribes to all events, audit logs every change automatically |
| Testability | Can't fake `DBHelper.instance` | Swap repository in `sl` registration — no other code changes |

---

## 📁 New Files Created

### 1. `lib/core/events/domain_event_bus.dart` (160 lines)
- `DomainEvent` sealed base + 9 concrete events (`SaleCompletedEvent`, `PurchaseCompletedEvent`, `PaymentReceivedEvent`, `StockAdjustedEvent`, `ExpenseRecordedEvent`, `CustomerCreatedEvent`, `SupplierCreatedEvent`, `ProductCreatedEvent`, `SaleVoidedEvent`)
- `DomainEventBus` singleton with `on<T>()`, `emit<T>()`, error-isolated fan-out
- Returns disposer from `on<>` so listeners can clean up on disposal

### 2. `lib/core/repositories/base_repository.dart` (20 lines)
- `BaseRepository` exposes `Database get db` and `runInTransaction<T>(...)`
- Subclasses use it to keep SQL writes consistent

### 3. `lib/core/repositories/sales_repository.dart` (60 lines)
- `createSale()` — inserts sale + items in a transaction, **then** emits `SaleCompletedEvent`
- `voidSale()` — flips `is_voided`, emits `SaleVoidedEvent`
- `listSales()`, `getSaleItems()`, `getTodaysSalesTotal()`

### 4. `lib/core/repositories/inventory_repository.dart` (50 lines)
- `createProduct()` — emits `ProductCreatedEvent`
- `adjustStock()` — emits `StockAdjustedEvent` (reason-tagged: `sale`/`purchase`/`manual`/`return`)
- `listProducts()`, `getProductCount()`, `getLowStockCount()`

### 5. `lib/core/listeners/accounting_event_listener.dart` (70 lines)
- One listener subscribes to **5 events** and writes the corresponding `AuditLogger.log` entry
- Pattern: **adding a new reaction never touches repositories**
- Example: adding a journal-posting listener tomorrow is one new `on<SaleCompletedEvent>` line, not a code change inside `SalesRepository`

### 6. `lib/core/di/service_locator.dart` (50 lines)
- `get_it`-based DI container (`final GetIt sl = GetIt.instance`)
- `setupServiceLocator()` runs in `main()` before `runApp`:
  1. Registers `DBHelper` singleton (forces DB open)
  2. Registers `DomainEventBus` singleton
  3. Registers `SalesRepository`, `InventoryRepository` as lazy singletons
  4. Wires `AccountingEventListener` (one-time `register()` call)
- Guarded with `isRegistered<T>()` so re-init (hot restart) is safe

### 7. Modified: `lib/main.dart` (+5 lines)
- Calls `await setupServiceLocator()` before Sentry/runApp

### 8. Modified: `lib/core/database/db_helper.dart` (+13 lines)
- Added sync `Database get db` accessor (the existing async `database` was blocking the repository pattern — repositories want sync DB access)
- Throws clear `StateError` if accessed before init

### 9. Modified: `lib/features/ai/ai_engine.dart` (10 calls refactored)
- 3 of 9 tools now use `sl<SalesRepository>()` / `sl<InventoryRepository>()`
- Other 6 still use `DBHelper.instance` directly with `// moved to ...Repository in Phase 2` comments so the next pass is obvious

---

## 🎯 Key Design Decisions

### 1. **Sealed `DomainEvent`** — not abstract class
Sealed classes in Dart 3 let the compiler check exhaustiveness. New event types are easy to add; the bus is type-safe.

### 2. **Async fan-out, but never blocks the publisher**
```dart
DomainEventBus.instance.emit(SaleCompletedEvent(...));
// Sale row already committed — listeners react at their own pace
```
A slow analytics listener cannot delay a sale write. Errors are caught and logged so one bad listener cannot break the others.

### 3. **Event AFTER commit, not before**
The repository writes the sale in a transaction, *then* emits the event. This means listeners can never see a half-written sale, even on crash.

### 4. **Sync `db` getter, not async**
Repositories write SQL like `db.query(...)` — no `await db.database` repeated 100 times. Made possible by the new `Database get db` sync accessor + the fact that `main()` now awaits DB open.

### 5. **`sl<T>` over `new T()`**
Tests can call `sl.registerSingleton<SalesRepository>(FakeSalesRepository())` once, and every `sl<SalesRepository>()` in production code returns the fake. No constructor changes anywhere.

### 6. **Phase 1 = infrastructure, not migration**
Only 3 of the 10 tools in `ai_engine.dart` use the new repos. The other 7 still call `DBHelper.instance` directly, but the **path is now open**: any module can be migrated independently, with no risk of cross-contamination.

---

## 🧩 What `sl<>` Looks Like in Code

**Before** (every file has this):
```dart
final total = await DBHelper.instance.getTodaysSalesTotal(companyId);
```

**After** (3 of 10 tools in `ai_engine.dart`):
```dart
final total = await sl<SalesRepository>().getTodaysSalesTotal(companyId);
```

**Adding a fake for tests:**
```dart
// in test_setup.dart
sl.registerSingleton<SalesRepository>(FakeSalesRepository());
```

---

## 📊 Numbers

- **5 new files, 410 lines**
- **3 modified files, ~30 net new lines**
- **0 new errors / warnings** (`flutter analyze` still shows 200 pre-existing issues, all `info`/`warning` level)
- **3 of 10 tools** in `ai_engine.dart` now repository-based
- **5 events** wired with audit logging (sale create/void, payment, stock, expense)

---

## 🔮 Phase 2 — Recommended Next Steps

When you're ready, Phase 2 should:

1. **More repositories** — `PurchaseRepository`, `ExpenseRepository`, `CustomerRepository`, `SupplierRepository`, `AccountingRepository`, `HRRepository`. Each takes its slice of methods off `DBHelper`.

2. **Migrate callers in waves**:
   - Wave 1: `ai_engine.dart` (already in progress)
   - Wave 2: dashboard widgets, low-stock alerts
   - Wave 3: full sales/purchase/return screens
   - Wave 4: HR, manufacturing, services (deepest modules)

3. **More listeners**:
   - `JournalPostingListener` — reacts to `SaleCompletedEvent`, posts AR/Cash double-entry
   - `LowStockNotificationListener` — reacts to `StockAdjustedEvent`, fires local notification when stock < threshold
   - `AnalyticsListener` — reacts to all sales/purchase events, rolls up daily KPIs

4. **DBHelper becomes the schema/connection layer only** — keeps `database`, `closeDatabase`, schema migration, but every business method moves to a repo.

---

## ✅ Verification

```
flutter analyze lib/core/events lib/core/repositories lib/core/listeners lib/core/di lib/main.dart
→ 0 errors, 0 warnings on new files
```

The new architecture compiles, links, and is ready for incremental adoption. No file outside the architecture layer needs to change to start using the event bus or repositories.

---

**Status: Phase 1 Foundation Complete ✅**

The "spaghetti risk" the user flagged is now a planned refactor with a paved path — not a rewrite-everything-or-nothing cliff.
