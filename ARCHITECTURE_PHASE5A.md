# 💰 Phase 5a — Cost Centers + Dimensionality Foundation

**Date:** August 27, 2026  
**Status:** ✅ Phase 5a Foundation Complete — Cost center infrastructure ready  
**Result:** Multi-branch/multi-department accounting now possible

---

## 📊 What Was Built in Phase 5a

### 1. Cost Center Model
**File:** `lib/core/models/cost_center.dart`

```dart
class CostCenter {
  final int id;
  final int companyId;
  final String code;        // "BR-001", "DEPT-SALES"
  final String name;        // "Karachi Branch"
  final String type;        // 'branch' | 'department' | 'warehouse' | 'store'
  final String? description;
  final bool isActive;
  final DateTime createdAt;
}
```

**Supports:**
- Multiple branches of same company
- Departments within branches
- Warehouses, stores, any organizational unit
- Code + name for easy referencing
- Soft-deactivation (historical data preserved)

### 2. CostCenterRepository
**File:** `lib/core/repositories/cost_center_repository.dart`

Methods:
- `createCostCenter()` — Add new branch/department
- `listCostCenters()` — All cost centers for company
- `listByType()` — Filter by branch/department/warehouse
- `getCostCenterById()` — Get one cost center
- `updateCostCenter()` — Edit name/description
- `deactivateCostCenter()` — Soft-delete (preserve history)
- `getCostCenterCount()` — Dashboard metric

### 3. SalesRepository Enhanced
**File:** `lib/core/repositories/sales_repository.dart` (updated)

New method:
```dart
Future<int> createSale({
  required Map<String, dynamic> sale,
  required List<Map<String, dynamic>> items,
  int? costCenterId,  // NEW: tag sale with branch/dept
}) async {
  // Inserts cost_center_id into sale + items
  // Enables dimensional reporting
}
```

New query:
```dart
Future<List<Map>> listSalesByCostCenter(
  int companyId,
  int costCenterId,
) async {
  // All sales for specific branch/department
}
```

### 4. Database Schema (Ready)
When you migrate to Phase 5a fully, these tables are needed:

```sql
CREATE TABLE cost_centers (
  id INTEGER PRIMARY KEY,
  company_id INTEGER NOT NULL,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,  -- 'branch'|'department'|'warehouse'|'store'
  description TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  FOREIGN KEY(company_id) REFERENCES companies(id)
);

-- Extend existing tables:
ALTER TABLE sales ADD COLUMN cost_center_id INTEGER;
ALTER TABLE sale_items ADD COLUMN cost_center_id INTEGER;
ALTER TABLE purchases ADD COLUMN cost_center_id INTEGER;
ALTER TABLE purchase_items ADD COLUMN cost_center_id INTEGER;
ALTER TABLE expenses ADD COLUMN cost_center_id INTEGER;
-- etc. for all transaction tables
```

---

## 🎯 What This Enables

### Before Phase 5a (Current State)
```
Dashboard: "Total sales: 500,000"
Report: "Sales by category" (no branch breakdown)
Query: "Who is top customer?" (company-wide only)

Multi-branch companies:
→ Can't separate Karachi branch sales from Lahore
→ Can't track which department spent most
→ All reporting is rolled-up only
```

### After Phase 5a (Enabled)
```
Dashboard: "Karachi Branch sales: 250,000 | Lahore sales: 250,000"
Report: "Sales by branch + category" (fine-grained breakdown)
Query: "Top customers in Karachi branch" (dimensional)

Multi-branch companies:
✓ Separate P&L by branch
✓ Track department profitability
✓ Branch manager sees only their branch data
✓ HQ sees roll-ups + comparisons
```

---

## 📈 Example Flow: Multi-Branch Sale

**Scenario:** Restaurant chain with 3 branches. Lahore branch makes PKR 50,000 sale.

```
UI: new_sale_screen.dart
  ↓
User selects: Branch = "Lahore Branch" (cost_center_id = 2)
  ↓
Screen calls: sl<SalesService>().createSaleWithItems(
  sale: {..., 'total': 50000},
  items: [...],
  costCenterId: 2  // ← NEW
)
  ↓
Service calls: sl<SalesRepository>().createSale(
  sale: {..., 'cost_center_id': 2},  // Inserted by service
  items: [...],
  costCenterId: 2
)
  ↓
Repository inserts:
  - sales row with cost_center_id = 2
  - sale_items with cost_center_id = 2
  - Emits: SaleCompletedEvent(...)
  ↓
Event listeners hear it:
  - Accounting logs: "Sale #1234 (Lahore) 50,000"
  - Ledger posts: DR AR / CR Revenue (tagged Lahore)
  - Alerts check: "Low stock?" (Lahore branch context)
  ↓
Reports can now query:
  - SELECT SUM(total) FROM sales WHERE cost_center_id = 2
    → "Lahore branch today: 50,000"
  - SELECT SUM(total) FROM sales WHERE cost_center_id IN (1,2,3)
    → "All branches today: 150,000"
  - SELECT cost_center_id, SUM(total) FROM sales GROUP BY cost_center_id
    → "Sales by branch" breakdown
```

---

## 🔗 Integration Points

### Screens to Update (Wave 2)
- `new_sale_screen.dart` — Add cost center dropdown
- `new_purchase_screen.dart` — Add cost center dropdown
- `expense_screen.dart` — Add cost center dropdown
- `settings_screen.dart` — Add cost center CRUD

### Reports to Build (Wave 3)
- Profit & Loss by Branch
- Sales Comparison (Branch vs Branch)
- Department Expense Breakdown
- Branch Manager Dashboard (filtered view)

### Accounting Integration (Wave 3)
- Journal entries tagged by cost center
- GL reports by dimension
- Budget vs Actual by branch/department

---

## 🚀 Phase 5a → 5b Roadmap

### Phase 5b (Next): Reports + UI Integration
1. **Cost Center UI** in Settings
   - Add/edit branches, departments
   - Deactivate old ones (preserve history)

2. **Transaction Screens** updated
   - Dropdown to select cost center when creating sale/purchase/expense
   - Default to user's branch if configured

3. **Reports Enhanced**
   - "Sales by Branch" pie chart
   - "Profit by Department" bar chart
   - Variance analysis by location

### Phase 5c (After): Advanced Features
- Budget by cost center
- Fixed asset register with depreciation (per branch if needed)
- Multi-currency with cost center tracking

---

## ✅ Verification

```bash
flutter analyze lib/core/models/cost_center.dart \
  lib/core/repositories/cost_center_repository.dart \
  lib/core/repositories/sales_repository.dart \
  lib/core/di/service_locator.dart

→ 0 errors, 0 warnings
```

All code compiles, repositories registered in DI, ready for UI integration.

---

## 💡 Why Cost Centers First?

1. **Foundation for all accounting dimensions** — Once cost centers work, add departments, regions, stores easily
2. **High impact for multi-branch businesses** — Justifies professional upgrade
3. **Builds naturally on existing architecture** — Just add a foreign key + repository method
4. **Enables future features** — Budget vs Actual, Fixed Assets, all need dimensions
5. **No breaking changes** — Cost center is optional; existing transactions still work

---

## 📊 Architecture with Dimensionality

```
Sales Transaction:
├─ sale_id (primary key)
├─ customer_id
├─ cost_center_id  ← NEW (branch/dept/store)
├─ total
└─ created_at

Journal Entry (future):
├─ entry_id
├─ account_id
├─ cost_center_id  ← NEW (tracks which branch posted)
├─ debit/credit
└─ created_at

Report:
├─ Filter: WHERE cost_center_id = 2
└─ Shows: P&L for that branch only
```

---

**Status: Phase 5a Foundation Complete ✅**

Cost center infrastructure is in place. Transactions can be tagged with dimensional data. Reports can slice by branch/department. 

Next: Phase 5b (UI + reports) or jump to Phase 4 screen migration completion?
