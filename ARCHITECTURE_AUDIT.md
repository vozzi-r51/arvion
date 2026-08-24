# DukanEdge Architecture & Feature Audit

## 1. Project baseline

Project name: DukanEdge
Framework: Flutter + Dart
Database: SQLite via `sqflite`
Auth: PIN + biometric support via `local_auth`
Storage: `shared_preferences`
File and export support: `share_plus`, `file_picker`, `archive`, `path_provider`
UI: Material 3 + Google Fonts
Offline-first design: yes, core app is intended to run without internet

## 2. Existing strengths

- Multi-company architecture is present in `lib/core/database/db_helper.dart`.
- Core app structure is organized by feature folders under `lib/features`.
- App start flow is structured around PIN setup/login and app lock logic in `lib/app.dart` and `lib/core/auth/auth_service.dart`.
- Database schema already includes many business domains: companies, products, customers, suppliers, sales, purchases, expenses, HR, committee, returns, challans, journal, audit log, stock adjustments, and staff users.
- Backup/restore, CSV export, and business reporting primitives exist in the project.
- There is a meaningful ERP shape already in place, not a blank app.

## 3. Existing modules observed

### Core app
- `lib/main.dart`
- `lib/app.dart`
- `lib/core/auth/auth_service.dart`
- `lib/core/database/db_helper.dart`
- `lib/core/theme/app_theme.dart`

### Finance / accounting
- `lib/features/journal/`
- `lib/features/ledger/`
- `lib/features/finance/`
- `lib/features/reports/`

### Sales / purchase / inventory
- `lib/features/sales/`
- `lib/features/purchases/`
- `lib/features/products/`
- `lib/features/customers/`
- `lib/features/returns/`
- `lib/features/challan/`
- `lib/features/purchase_order/`

### HR and staff
- `lib/features/hr/`
- `lib/features/committee/`
- `lib/features/cheque/`

### Company / settings / auth
- `lib/features/company/`
- `lib/features/settings/`
- `lib/features/auth/`
- `lib/features/more/`

### Utility / exports
- `lib/core/export/csv_export_service.dart`
- `lib/core/backup/backup_service.dart`
- `lib/core/audit/audit_logger.dart`

## 4. Database audit summary

The SQLite schema is broad and already crosses multiple ERP domains. It includes:

- companies
- app_security
- categories
- brands
- products
- customers
- suppliers
- sales and sale items
- purchases and purchase items
- expenses, income
- ledger-related tables
- HR tables
- committee and cheque tables
- returns tables
- challan and purchase-order tables
- audit log
- stock adjustments
- journal + chart of accounts
- staff users

This is a strong starting point but the application still needs discipline around:

- financial transaction integrity
- stricter accounting engine centralization
- prevention of silent destructive changes
- schema migration validation
- consistent cross-module accounting posting

## 5. Missing or partial areas

The project already has significant breadth, but the following areas are still missing or not fully production-grade:

1. Centralized double-entry accounting engine
   - Journal logic exists, but not yet enforced as a single system for all financial events.

2. Strict data safety and rollback rules
   - Some modules are present without a universal financial rollback strategy.

3. Accounting consistency checks
   - Trial balance / ledger reconciliation is not yet the single source of truth for all financial modules.

4. Hard enforcement of stock movement + accounting posting together
   - Inventory and accounting updates need a shared transactional boundary.

5. True multi-phase migration verification
   - Schema versioning exists, but full migration validation for every module is still needed.

6. Reporting normalization
   - Some report screens are present, but they need full reconciliation against actual ledger balances.

7. Permission / approval enforcement
   - The app has role-friendly shape, but it is not yet hardened as a true business control system.

8. Production-grade backup/restore integrity checks
   - Backup logic is present but not yet fully hardened against bad or interrupted restores.

9. Full audit coverage across all financial modules
   - Audit logging is present for some modules, but not yet universal across all financial operations.

10. Complete ERP feature depth
   - The app has many features, but several are still shell-level or partial and need actual accounting linkage before being called production-ready.

## 6. Technical debt and risks

- Some previous compatibility issues were caused by Flutter version upgrades, especially around `CardTheme` and `share_plus` API differences.
- The project uses a broad set of plugins; a large ERP can break if plugin APIs drift.
- There are likely many screens with partial workflows rather than a single unified accounting lifecycle.
- A single app with many modules can easily drift into inconsistent states if the team does not enforce a single posting layer.
- A strong ERP should treat sales, purchases, returns, expenses, payroll, and cash movements as one accounting stream, not separate local events.

## 7. Offline-first assessment

Status: good foundation, but needs strict validation.

The app is designed to be local-first and does not require internet for core local workflows. That is positive.

However, actual business correctness must be validated by workflow tests:

- Sale updates inventory + customer + accounting
- Purchase updates inventory + supplier + accounting
- Payment updates customer/supplier ledgers
- Return reverses stock and ledger state
- Expense posts to correct expense account
- Cash/bank balances reconcile
- Backup/restore preserves data integrity

## 8. Current known state after project review

The project has already crossed the initial app scaffold and basic ERP structure. The app is not a blank demo; it is a real base ERP with multiple modules.

The major action point is not to rebuild everything from scratch. It is to enforce a strong, phase-based architecture around:

1. centralized accounting engine
2. database transaction integrity
3. migration safety
4. report correctness
5. audit and permissions
6. clean ERP workflow implementation

## 9. Recommended next phase

### Phase 1: Offline-first hardening and accounting integrity

This is the immediate next phase because it is the highest-value and most important requirement from the master prompt.

Focus on:
- enforcing atomic transactions for sales, purchases, payments, returns, and expenses
- centralizing journal posting
- validating debit vs credit
- enforcing database integrity checks
- standardizing audit log entries
- validating backup/restore safety

## 10. Core development rule

The app should not add more modules in parallel while the accounting core remains inconsistent. The correct approach is:

- keep the existing project structure
- fix the accounting flow at the service layer
- validate with real transactions
- only then move to the next module group

## 11. Deliverable status

This document satisfies the baseline requirement for Phase 0: Architecture & Feature Audit.

Next required work:
- Phase 1 foundation hardening
- transaction-safe accounting service layer
- migration validation
- real offline workflow tests
