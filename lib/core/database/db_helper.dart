import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite helper for the whole app.
///
/// Multi-company design: instead of a separate .db file per company (which
/// makes backup/restore and cross-company reporting painful), we use ONE
/// database file with a `companies` table, and every business table created
/// in later phases carries a `company_id` foreign key column. All queries
/// for business data must filter by the currently active company_id, which
/// is tracked separately (see ActiveCompanyStore in auth_service.dart).
class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  /// Closes the current connection so the underlying .db file can be safely
  /// overwritten (used by Restore). The next call to `database` will
  /// transparently reopen it.
  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dukanedge.db');

    return openDatabase(
      path,
      version: 21,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enforce FK constraints (important once product/customer tables
        // reference company_id in later phases).
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Security: harden DB file handling and verify assumptions before writing.
    if (oldVersion < 2) {
      // Phase 2: extra company-profile fields (Invoice Designer needs these
      // later — stamp, signature, footer, extra company details).
      await db.execute('ALTER TABLE companies ADD COLUMN shop_stamp_path TEXT');
      await db.execute('ALTER TABLE companies ADD COLUMN signature_path TEXT');
      await db.execute('ALTER TABLE companies ADD COLUMN invoice_footer TEXT');
      await db.execute('ALTER TABLE companies ADD COLUMN company_details TEXT');
    }
    if (oldVersion < 3) {
      // Phase 3: Category / Brand / Product management.
      await _createCategoryBrandProductTables(db);
    }
    if (oldVersion < 4) {
      // Phase 4: Customer / Supplier management.
      await _createCustomerSupplierTables(db);
    }
    if (oldVersion < 5) {
      // Phase 5: Sales / POS module.
      await _createSalesTables(db);
    }
    if (oldVersion < 6) {
      // Phase 6: Purchase module.
      await _createPurchaseTables(db);
    }
    if (oldVersion < 7) {
      // Phase 7: Expenses & Income module.
      await _createExpenseIncomeTables(db);
    }
    if (oldVersion < 8) {
      // Phase 8: Customer/Supplier Ledger, Cash Book, Bank Book.
      await _createLedgerTables(db);
    }
    if (oldVersion < 9) {
      // Phase 11: Employees / HR (attendance, salary, advance, commission).
      await _createHrTables(db);
    }
    if (oldVersion < 10) {
      // Phase 12: Committee (BC System) + Cheque Management.
      await _createCommitteeChequeTables(db);
    }
    if (oldVersion < 11) {
      // Phase 14: Sales Return / Purchase Return.
      await _createReturnsTables(db);
    }
    if (oldVersion < 12) {
      // Phase 15: Delivery Challan + Purchase Order.
      await _createChallanPoTables(db);
    }
    if (oldVersion < 13) {
      // Phase 16: Audit Log.
      await _createAuditLogTable(db);
    }
    if (oldVersion < 14) {
      // Gap-fill: Inventory Adjustment.
      await _createStockAdjustmentsTable(db);
    }
    if (oldVersion < 15) {
      // Gap-fill 2: Journal/Trial Balance, soft-delete columns.
      await _createJournalTables(db);
      await db.execute('ALTER TABLE products ADD COLUMN deleted_at TEXT');
      await db.execute('ALTER TABLE customers ADD COLUMN deleted_at TEXT');
      await db.execute('ALTER TABLE suppliers ADD COLUMN deleted_at TEXT');
      await db.execute('ALTER TABLE employees ADD COLUMN deleted_at TEXT');
    }
    if (oldVersion < 19) {
      await db.execute('ALTER TABLE app_security ADD COLUMN security_question TEXT');
      await db.execute('ALTER TABLE app_security ADD COLUMN security_answer TEXT');
    }
    if (oldVersion < 20) {
      await db.execute('ALTER TABLE products ADD COLUMN base_unit TEXT DEFAULT "Pc"');
      await db.execute('ALTER TABLE products ADD COLUMN secondary_unit TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN conversion_factor REAL DEFAULT 1');
    }
    if (oldVersion < 21) {
      await db.execute('ALTER TABLE journal_entries ADD COLUMN source_type TEXT');
      await db.execute('ALTER TABLE journal_entries ADD COLUMN source_id INTEGER');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // --- Companies table (core to multi-company support) ---
    await db.execute('''
      CREATE TABLE companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner_name TEXT,
        address TEXT,
        phone TEXT,
        whatsapp TEXT,
        email TEXT,
        logo_path TEXT,
        shop_stamp_path TEXT,
        signature_path TEXT,
        invoice_footer TEXT,
        company_details TEXT,
        ntn_gst TEXT,
        default_tax_percent REAL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // --- App security table (PIN + biometric preference) ---
    // App-level lock: one PIN unlocks the app; each company's data is then
    // separated internally by company_id.
    await db.execute('''
      CREATE TABLE app_security (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        security_question TEXT,
        security_answer TEXT,
        biometric_enabled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createCategoryBrandProductTables(db);
    await _createCustomerSupplierTables(db);
    await _createSalesTables(db);
    await _createPurchaseTables(db);
    await _createExpenseIncomeTables(db);
    await _createLedgerTables(db);
    await _createHrTables(db);
    await _createCommitteeChequeTables(db);
    await _createReturnsTables(db);
    await _createChallanPoTables(db);
    await _createAuditLogTable(db);
    await _createStockAdjustmentsTable(db);
    await _createJournalTables(db);
    await _createStaffUsersTable(db);
  }

  Future<void> _createStaffUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE staff_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');
  }

  Future<void> _createJournalTables(Database db) async {
    await db.execute('''
      CREATE TABLE chart_of_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        code TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        description TEXT NOT NULL,
        source_type TEXT,
        source_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE journal_entry_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journal_entry_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        debit REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (journal_entry_id) REFERENCES journal_entries (id),
        FOREIGN KEY (account_id) REFERENCES chart_of_accounts (id)
      )
    ''');
  }

  Future<void> _createStockAdjustmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT,
        adjustment_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  Future<void> _createCategoryBrandProductTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        code TEXT,
        name TEXT NOT NULL,
        urdu_name TEXT,
        parent_id INTEGER,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (parent_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE brands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        code TEXT,
        name TEXT NOT NULL,
        urdu_name TEXT,
        company_name TEXT,
        country TEXT,
        website TEXT,
        email TEXT,
        phone TEXT,
        logo_path TEXT,
        featured INTEGER NOT NULL DEFAULT 0,
        display_order INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        product_code TEXT,
        barcode TEXT,
        qr_code TEXT,
        sku TEXT,
        name TEXT NOT NULL,
        urdu_name TEXT,
        category_id INTEGER,
        brand_id INTEGER,
        purchase_price REAL NOT NULL DEFAULT 0,
        retail_price REAL NOT NULL DEFAULT 0,
        wholesale_price REAL NOT NULL DEFAULT 0,
        current_stock REAL NOT NULL DEFAULT 0,
        low_stock_level REAL NOT NULL DEFAULT 0,
        batch_number TEXT,
        expiry_date TEXT,
        image_path TEXT,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        packing TEXT,
        base_unit TEXT DEFAULT 'Pc',
        secondary_unit TEXT,
        conversion_factor REAL DEFAULT 1,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (brand_id) REFERENCES brands (id)
      )
    ''');
  }

  Future<void> _createCustomerSupplierTables(Database db) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        customer_code TEXT,
        name TEXT NOT NULL,
        urdu_name TEXT,
        mobile TEXT,
        whatsapp TEXT,
        address TEXT,
        cnic TEXT,
        credit_limit REAL NOT NULL DEFAULT 0,
        opening_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        customer_type TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        deleted_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        supplier_code TEXT,
        company_name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        whatsapp TEXT,
        address TEXT,
        email TEXT,
        ntn TEXT,
        opening_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        payment_terms TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');
  }

  Future<void> _createSalesTables(Database db) async {
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        invoice_number TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        sale_type TEXT NOT NULL DEFAULT 'cash',
        subtotal REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        due_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT,
        sale_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        purchase_price REAL NOT NULL DEFAULT 0,
        packing TEXT,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  Future<void> _createPurchaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        invoice_number TEXT NOT NULL,
        supplier_id INTEGER,
        supplier_name TEXT,
        purchase_type TEXT NOT NULL DEFAULT 'cash',
        subtotal REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        due_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT,
        purchase_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        packing TEXT,
        total REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  Future<void> _createExpenseIncomeTables(Database db) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        expense_date TEXT NOT NULL,
        payment_method TEXT,
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        income_date TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');
  }

  Future<void> _createLedgerTables(Database db) async {
    await db.execute('''
      CREATE TABLE customer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        payment_date TEXT NOT NULL,
        payment_method TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        payment_date TEXT NOT NULL,
        payment_method TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        category TEXT,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        bank_name TEXT NOT NULL,
        account_title TEXT,
        account_number TEXT,
        opening_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        bank_account_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (bank_account_id) REFERENCES bank_accounts (id)
      )
    ''');
  }

  Future<void> _createHrTables(Database db) async {
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        employee_code TEXT,
        name TEXT NOT NULL,
        urdu_name TEXT,
        phone TEXT,
        address TEXT,
        cnic TEXT,
        designation TEXT,
        department TEXT,
        monthly_salary REAL NOT NULL DEFAULT 0,
        joining_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        check_in TEXT,
        check_out TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (employee_id) REFERENCES employees (id),
        UNIQUE (employee_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE salary_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        payment_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE advance_salary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        recovered_amount REAL NOT NULL DEFAULT 0,
        advance_date TEXT NOT NULL,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE commissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        commission_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');
  }

  Future<void> _createCommitteeChequeTables(Database db) async {
    await db.execute('''
      CREATE TABLE committees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        monthly_installment REAL NOT NULL DEFAULT 0,
        total_members INTEGER NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL,
        duration_months INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE committee_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        committee_id INTEGER NOT NULL,
        member_name TEXT NOT NULL,
        phone TEXT,
        join_date TEXT NOT NULL,
        has_drawn INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (committee_id) REFERENCES committees (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE committee_installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        committee_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        payment_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (committee_id) REFERENCES committees (id),
        FOREIGN KEY (member_id) REFERENCES committee_members (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE committee_draws (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        committee_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        draw_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (committee_id) REFERENCES committees (id),
        FOREIGN KEY (member_id) REFERENCES committee_members (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE cheques (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        party_name TEXT NOT NULL,
        bank_name TEXT,
        cheque_number TEXT,
        amount REAL NOT NULL DEFAULT 0,
        cheque_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');
  }

  Future<void> _createReturnsTables(Database db) async {
    await db.execute('''
      CREATE TABLE sales_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        sale_id INTEGER,
        customer_id INTEGER,
        customer_name TEXT,
        return_number TEXT NOT NULL,
        return_date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        refund_method TEXT NOT NULL DEFAULT 'cash',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (return_id) REFERENCES sales_returns (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        purchase_id INTEGER,
        supplier_id INTEGER,
        supplier_name TEXT,
        return_number TEXT NOT NULL,
        return_date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (purchase_id) REFERENCES purchases (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (return_id) REFERENCES purchase_returns (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  Future<void> _createChallanPoTables(Database db) async {
    await db.execute('''
      CREATE TABLE delivery_challans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        challan_number TEXT NOT NULL,
        sale_id INTEGER,
        customer_id INTEGER,
        customer_name TEXT,
        challan_date TEXT NOT NULL,
        delivery_address TEXT,
        delivery_status TEXT NOT NULL DEFAULT 'pending',
        signature_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE delivery_challan_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        challan_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        FOREIGN KEY (challan_id) REFERENCES delivery_challans (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        po_number TEXT NOT NULL,
        supplier_id INTEGER,
        supplier_name TEXT,
        po_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        total_amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        po_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (po_id) REFERENCES purchase_orders (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  Future<void> _createAuditLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        module TEXT NOT NULL,
        action TEXT NOT NULL,
        description TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');
  }

  // ---------------- Company helpers ----------------

  Future<int> insertCompany(Map<String, dynamic> company) async {
    final db = await database;
    final id = await db.insert('companies', company);
    await ensureChartOfAccounts(id);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final db = await database;
    return db.query('companies', orderBy: 'id ASC');
  }

  Future<void> setActiveCompany(int companyId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('companies', {'is_active': 0});
      await txn.update(
        'companies',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [companyId],
      );
    });
  }

  Future<Map<String, dynamic>?> getActiveCompany() async {
    final db = await database;
    final rows = await db.query(
      'companies',
      where: 'is_active = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getCompanyById(int id) async {
    final db = await database;
    final rows = await db.query('companies', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateCompany(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('companies', data, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- App security helpers ----------------

  Future<bool> hasPinSetup() async {
    final db = await database;
    final rows = await db.query('app_security', where: 'id = 1');
    return rows.isNotEmpty;
  }

  Future<void> savePin(String pinHash, String salt, {String? question, String? answer}) async {
    final db = await database;
    await db.insert(
      'app_security',
      {
        'id': 1,
        'pin_hash': pinHash,
        'pin_salt': salt,
        'security_question': question,
        'security_answer': answer,
        'biometric_enabled': 0
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getSecurityRow() async {
    final db = await database;
    final rows = await db.query('app_security', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final db = await database;
    await db.update(
      'app_security',
      {'biometric_enabled': enabled ? 1 : 0},
      where: 'id = 1',
    );
  }

  // ---------------- Category helpers ----------------

  Future<int> insertCategory(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('categories', data);
  }

  Future<List<Map<String, dynamic>>> getCategories(int companyId) async {
    final db = await database;
    return db.query('categories',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'name ASC');
  }

  Future<void> updateCategory(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('categories', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Brand helpers ----------------

  Future<int> insertBrand(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('brands', data);
  }

  Future<List<Map<String, dynamic>>> getBrands(int companyId) async {
    final db = await database;
    return db.query('brands',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'display_order ASC, name ASC');
  }

  Future<void> updateBrand(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('brands', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBrand(int id) async {
    final db = await database;
    await db.delete('brands', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Product helpers ----------------

  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('products', data);
  }

  Future<List<Map<String, dynamic>>> getProducts(int companyId,
      {String? searchQuery, int? limit, int? offset}) async {
    final db = await database;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return db.query(
        'products',
        where: 'company_id = ? AND deleted_at IS NULL AND (name LIKE ? OR product_code LIKE ? OR barcode LIKE ?)',
        whereArgs: [companyId, '%$searchQuery%', '%$searchQuery%', '%$searchQuery%'],
        orderBy: 'name ASC',
        limit: limit,
        offset: offset,
      );
    }
    return db.query('products',
        where: 'company_id = ? AND deleted_at IS NULL', whereArgs: [companyId], orderBy: 'name ASC',
        limit: limit, offset: offset);
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('products', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.update('products', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDeletedProducts(int companyId) async {
    final db = await database;
    return db.query('products',
        where: 'company_id = ? AND deleted_at IS NOT NULL', whereArgs: [companyId], orderBy: 'deleted_at DESC');
  }

  Future<void> restoreProduct(int id) async {
    final db = await database;
    await db.update('products', {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> permanentlyDeleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getProductCount(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE company_id = ?',
        [companyId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getLowStockCount(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE company_id = ? AND current_stock <= low_stock_level',
        [companyId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------- Customer helpers ----------------

  Future<int> insertCustomer(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('customers', data);
  }

  Future<List<Map<String, dynamic>>> getCustomers(int companyId,
      {String? searchQuery}) async {
    final db = await database;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return db.query(
        'customers',
        where: 'company_id = ? AND deleted_at IS NULL AND (name LIKE ? OR mobile LIKE ?)',
        whereArgs: [companyId, '%$searchQuery%', '%$searchQuery%'],
        orderBy: 'name ASC',
      );
    }
    return db.query('customers',
        where: 'company_id = ? AND deleted_at IS NULL', whereArgs: [companyId], orderBy: 'name ASC');
  }

  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('customers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.update('customers', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDeletedCustomers(int companyId) async {
    final db = await database;
    return db.query('customers',
        where: 'company_id = ? AND deleted_at IS NOT NULL', whereArgs: [companyId], orderBy: 'deleted_at DESC');
  }

  Future<void> restoreCustomer(int id) async {
    final db = await database;
    await db.update('customers', {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> permanentlyDeleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCustomerCount(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM customers WHERE company_id = ?',
        [companyId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------- Supplier helpers ----------------

  Future<int> insertSupplier(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('suppliers', data);
  }

  Future<List<Map<String, dynamic>>> getSuppliers(int companyId,
      {String? searchQuery}) async {
    final db = await database;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return db.query(
        'suppliers',
        where: 'company_id = ? AND deleted_at IS NULL AND (company_name LIKE ? OR phone LIKE ?)',
        whereArgs: [companyId, '%$searchQuery%', '%$searchQuery%'],
        orderBy: 'company_name ASC',
      );
    }
    return db.query('suppliers',
        where: 'company_id = ? AND deleted_at IS NULL',
        whereArgs: [companyId],
        orderBy: 'company_name ASC');
  }

  Future<void> updateSupplier(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('suppliers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSupplier(int id) async {
    final db = await database;
    await db.update('suppliers', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDeletedSuppliers(int companyId) async {
    final db = await database;
    return db.query('suppliers',
        where: 'company_id = ? AND deleted_at IS NOT NULL', whereArgs: [companyId], orderBy: 'deleted_at DESC');
  }

  Future<void> restoreSupplier(int id) async {
    final db = await database;
    await db.update('suppliers', {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> permanentlyDeleteSupplier(int id) async {
    final db = await database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getSupplierCount(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM suppliers WHERE company_id = ?',
        [companyId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getSupplierById(int id) async {
    final db = await database;
    final rows = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------- Sales helpers ----------------

  Future<String> generateInvoiceNumber(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM sales WHERE company_id = ?', [companyId]);
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return 'INV-${count.toString().padLeft(6, '0')}';
  }

  /// Saves a sale + its items in one transaction, deducts stock for each
  /// product, and (for due sales) increases the customer's current_balance.
  /// Also posts automated journal entries for Accounting.
  Future<int> insertSaleWithItems({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    bool allowNegativeStock = true,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      await _validateInventoryItems(
        txn,
        sale['company_id'] as int,
        items,
        priceKey: 'unit_price',
        allowNegativeStock: allowNegativeStock,
      );
      final saleId = await txn.insert('sales', sale);
      final companyId = sale['company_id'] as int;
      final saleDate = sale['sale_date'] as String;
      final invoiceNum = sale['invoice_number'] as String;

      double totalCost = 0;

      for (final item in items) {
        await txn.insert('sale_items', {
          ...item,
          'sale_id': saleId,
        });

        final productId = item['product_id'] as int?;
        final qty = item['quantity'] as num;
        final pPrice = (item['purchase_price'] as num?)?.toDouble() ?? 0;
        totalCost += pPrice * qty.toDouble();

        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [qty, productId],
          );
        }
      }

      final customerId = sale['customer_id'] as int?;
      final dueAmount = (sale['due_amount'] as num).toDouble();
      final totalAmount = (sale['total_amount'] as num).toDouble();
      final paidAmount = (sale['paid_amount'] as num).toDouble();

      if (customerId != null && dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
          [dueAmount, customerId],
        );
      }

      // --- AUTOMATED ACCOUNTING ENTRIES ---
      await _ensureChartOfAccountsInTransaction(txn, companyId);
      final coaRows = await txn.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
      int? getAccId(String name) {
        try { return coaRows.firstWhere((r) => r['name'] == name)['id'] as int; } catch(_) { return null; }
      }

      final cashAcc = getAccId('Cash');
      final recAcc = getAccId('Accounts Receivable');
      final salesAcc = getAccId('Sales Revenue');
      final cogsAcc = getAccId('Cost of Goods Sold');
      final invAcc = getAccId('Inventory');

      if (cashAcc == null || recAcc == null || salesAcc == null || cogsAcc == null || invAcc == null) {
        throw StateError('Accounting for Sales is not fully configured (Missing AR, Sales, COGS, or Inventory accounts).');
      }

      final List<Map<String, dynamic>> journalLines = [];

      // 1. Revenue Entry
      if (paidAmount > 0) {
        journalLines.add({'account_id': cashAcc, 'debit': paidAmount, 'credit': 0.0});
      }
      if (dueAmount > 0) {
        journalLines.add({'account_id': recAcc, 'debit': dueAmount, 'credit': 0.0});
      }
      if (totalAmount > 0) {
        journalLines.add({'account_id': salesAcc, 'debit': 0.0, 'credit': totalAmount});
      }

      // 2. COGS Entry (if cost data exists)
      if (totalCost > 0) {
        journalLines.add({'account_id': cogsAcc, 'debit': totalCost, 'credit': 0.0});
        journalLines.add({'account_id': invAcc, 'debit': 0.0, 'credit': totalCost});
      }

      if (journalLines.isNotEmpty) {
        await postAutomatedEntry(txn,
            companyId: companyId,
            date: saleDate,
            description: 'Auto: Sale Invoice $invoiceNum',
            sourceType: 'sale',
            sourceId: saleId,
            lines: journalLines);
      }

      return saleId;
    });
  }

  Future<List<Map<String, dynamic>>> getSales(int companyId, {int? limit, int? offset}) async {
    final db = await database;
    return db.query('sales',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC',
        limit: limit, offset: offset);
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  Future<void> voidSale(int saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (rows.isEmpty) return;
      final sale = rows.first;
      if (sale['status'] == 'voided') return;

      final companyId = sale['company_id'] as int;
      final invoiceNum = sale['invoice_number'] as String;
      final customerId = sale['customer_id'] as int?;
      final dueAmount = (sale['due_amount'] as num).toDouble();

      // Reverse Stock
      final items = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      for (final item in items) {
        final productId = item['product_id'] as int?;
        final qty = item['quantity'] as num;
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [qty, productId],
          );
        }
      }

      // Reverse Customer Balance
      if (customerId != null && dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE customers SET current_balance = current_balance - ? WHERE id = ?',
          [dueAmount, customerId],
        );
      }

      // Create Reversal Journal
      final journals = await txn.query('journal_entries', 
          where: 'company_id = ? AND source_type = ? AND source_id = ?', 
          whereArgs: [companyId, 'sale', saleId]);
      
      if (journals.isNotEmpty) {
        final journalId = journals.first['id'] as int;
        final lines = await txn.query('journal_entry_lines', where: 'journal_entry_id = ?', whereArgs: [journalId]);
        
        final reversalLines = lines.map((l) => {
          'account_id': l['account_id'],
          'debit': l['credit'],
          'credit': l['debit'],
        }).toList();

        await postAutomatedEntry(txn, 
            companyId: companyId, 
            date: DateTime.now().toIso8601String(), 
            description: 'VOID: Sale Invoice $invoiceNum',
            sourceType: 'reversal',
            sourceId: journalId,
            lines: reversalLines);
      }

      await txn.update('sales', {'status': 'voided'}, where: 'id = ?', whereArgs: [saleId]);
    });
  }

  Future<void> deleteSale(int saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }

  /// Sum of today's completed sale totals for this company.
  Future<double> getTodaysSalesTotal(int companyId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT SUM(total_amount) as total FROM sales WHERE company_id = ? AND substr(sale_date, 1, 10) = ?",
      [companyId, today],
    );
    final value = result.first['total'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  /// Today's profit = sum over today's sale_items of (unit_price -
  /// purchase_price) * quantity.
  Future<double> getTodaysProfit(int companyId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT SUM((si.unit_price - si.purchase_price) * si.quantity) as profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.company_id = ? AND substr(s.sale_date, 1, 10) = ?
    ''', [companyId, today]);
    final value = result.first['profit'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  // ---------------- Purchase helpers ----------------

  Future<String> generatePurchaseInvoiceNumber(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM purchases WHERE company_id = ?', [companyId]);
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return 'PUR-${count.toString().padLeft(6, '0')}';
  }

  /// Saves a purchase + its items in one transaction, increases stock for
  /// each product (and refreshes its purchase_price to the latest cost),
  /// and (for due purchases) increases the supplier's current_balance.
  /// Also posts automated journal entries for Accounting.
  Future<int> insertPurchaseWithItems({
    required Map<String, dynamic> purchase,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      await _validateInventoryItems(
        txn,
        purchase['company_id'] as int,
        items,
        priceKey: 'unit_cost',
      );
      final purchaseId = await txn.insert('purchases', purchase);
      final companyId = purchase['company_id'] as int;
      final purchaseDate = purchase['purchase_date'] as String;
      final invoiceNum = purchase['invoice_number'] as String;

      for (final item in items) {
        await txn.insert('purchase_items', {
          ...item,
          'purchase_id': purchaseId,
        });

        final productId = item['product_id'] as int?;
        final qty = (item['quantity'] as num).toDouble();
        final unitCost = (item['unit_cost'] as num).toDouble();

        if (productId != null) {
          // Calculate Weighted Average Cost
          final pRows = await txn.query('products',
              columns: ['current_stock', 'purchase_price'],
              where: 'id = ?',
              whereArgs: [productId]);

          double newAvgCost = unitCost;
          if (pRows.isNotEmpty) {
            final currentStock = (pRows.first['current_stock'] as num).toDouble();
            final currentPrice = (pRows.first['purchase_price'] as num).toDouble();

            if (currentStock > 0) {
              newAvgCost = ((currentStock * currentPrice) + (qty * unitCost)) /
                  (currentStock + qty);
            }
          }

          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ?, purchase_price = ? WHERE id = ?',
            [qty, newAvgCost, productId],
          );
        }
      }

      final supplierId = purchase['supplier_id'] as int?;
      final dueAmount = (purchase['due_amount'] as num).toDouble();
      final totalAmount = (purchase['total_amount'] as num).toDouble();
      final paidAmount = (purchase['paid_amount'] as num).toDouble();

      if (supplierId != null && dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET current_balance = current_balance + ? WHERE id = ?',
          [dueAmount, supplierId],
        );
      }

      // --- AUTOMATED ACCOUNTING ENTRIES ---
      await _ensureChartOfAccountsInTransaction(txn, companyId);
      final coaRows = await txn.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
      int? getAccId(String name) {
        try { return coaRows.firstWhere((r) => r['name'] == name)['id'] as int; } catch(_) { return null; }
      }

      final cashAcc = getAccId('Cash');
      final payAcc = getAccId('Accounts Payable');
      final invAcc = getAccId('Inventory');

      if (cashAcc == null || payAcc == null || invAcc == null) {
        throw StateError('Accounting for Purchases is not fully configured (Missing Cash, AP, or Inventory accounts).');
      }

      final List<Map<String, dynamic>> journalLines = [];

      if (totalAmount > 0) {
        journalLines.add({'account_id': invAcc, 'debit': totalAmount, 'credit': 0.0});
      }
      if (paidAmount > 0) {
        journalLines.add({'account_id': cashAcc, 'debit': 0.0, 'credit': paidAmount});
      }
      if (dueAmount > 0) {
        journalLines.add({'account_id': payAcc, 'debit': 0.0, 'credit': dueAmount});
      }

      if (journalLines.isNotEmpty) {
        await postAutomatedEntry(txn,
            companyId: companyId,
            date: purchaseDate,
            description: 'Auto: Purchase Invoice $invoiceNum',
            sourceType: 'purchase',
            sourceId: purchaseId,
            lines: journalLines);
      }

      return purchaseId;
    });
  }

  Future<List<Map<String, dynamic>>> getPurchases(int companyId, {int? limit, int? offset}) async {
    final db = await database;
    return db.query('purchases',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC',
        limit: limit, offset: offset);
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    final db = await database;
    return db.query('purchase_items',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
  }

  Future<void> voidPurchase(int purchaseId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('purchases', where: 'id = ?', whereArgs: [purchaseId]);
      if (rows.isEmpty) return;
      final purchase = rows.first;
      if (purchase['status'] == 'voided') return;

      final companyId = purchase['company_id'] as int;
      final invoiceNum = purchase['invoice_number'] as String;
      final supplierId = purchase['supplier_id'] as int?;
      final dueAmount = (purchase['due_amount'] as num).toDouble();

      // Reverse Stock (Deduct what was added)
      final items = await txn.query('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
      for (final item in items) {
        final productId = item['product_id'] as int?;
        final qty = item['quantity'] as num;
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [qty, productId],
          );
        }
      }

      // Reverse Supplier Balance
      if (supplierId != null && dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET current_balance = current_balance - ? WHERE id = ?',
          [dueAmount, supplierId],
        );
      }

      // Create Reversal Journal
      final journals = await txn.query('journal_entries', 
          where: 'company_id = ? AND source_type = ? AND source_id = ?', 
          whereArgs: [companyId, 'purchase', purchaseId]);
      
      if (journals.isNotEmpty) {
        final journalId = journals.first['id'] as int;
        final lines = await txn.query('journal_entry_lines', where: 'journal_entry_id = ?', whereArgs: [journalId]);
        
        final reversalLines = lines.map((l) => {
          'account_id': l['account_id'],
          'debit': l['credit'],
          'credit': l['debit'],
        }).toList();

        await postAutomatedEntry(txn, 
            companyId: companyId, 
            date: DateTime.now().toIso8601String(), 
            description: 'VOID: Purchase Invoice $invoiceNum',
            sourceType: 'reversal',
            sourceId: journalId,
            lines: reversalLines);
      }

      await txn.update('purchases', {'status': 'voided'}, where: 'id = ?', whereArgs: [purchaseId]);
    });
  }

  Future<void> deletePurchase(int purchaseId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('purchase_items',
          where: 'purchase_id = ?', whereArgs: [purchaseId]);
      await txn.delete('purchases', where: 'id = ?', whereArgs: [purchaseId]);
    });
  }

  /// Sum of today's purchase totals for this company.
  Future<double> getTodaysPurchaseTotal(int companyId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT SUM(total_amount) as total FROM purchases WHERE company_id = ? AND substr(purchase_date, 1, 10) = ?",
      [companyId, today],
    );
    final value = result.first['total'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  // ---------------- Expense helpers ----------------

  Future<int> insertExpense(Map<String, dynamic> data) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final companyId = data['company_id'] as int;
      final amount = _validateLedgerAmount(data['amount'], 'Expense');
      final category = data['category'] as String;
      final date = data['expense_date'] as String;
      final method = data['payment_method'] as String? ?? 'Cash';
      final expenseId = await txn.insert('expenses', data);

      // Automated Accounting
      final coaRows = await txn.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
      int? getAccId(String name) {
        try { return coaRows.firstWhere((r) => r['name'].toString().toLowerCase() == name.toLowerCase())['id'] as int; } catch(_) { return null; }
      }

      int? expAccId = getAccId(category);
      if (expAccId == null) expAccId = getAccId('Operating Expenses');
      
      int? sourceAccId = getAccId(method);
      if (sourceAccId == null) sourceAccId = getAccId('Cash');

      if (expAccId == null || sourceAccId == null) {
        throw StateError('Expense accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: companyId,
          date: date,
          description: 'Auto: Expense #$expenseId - $category',
          sourceType: 'expense',
          sourceId: expenseId,
          lines: [
            {'account_id': expAccId, 'debit': amount, 'credit': 0.0},
            {'account_id': sourceAccId, 'debit': 0.0, 'credit': amount},
          ]);

      return expenseId;
    });
  }

  Future<List<Map<String, dynamic>>> getExpenses(int companyId) async {
    final db = await database;
    return db.query('expenses',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<void> updateExpense(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('expenses', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final oldExpense = rows.first;
      final updatedExpense = {...oldExpense, ...data};
      final amount = _validateLedgerAmount(updatedExpense['amount'], 'Expense');
      final companyId = updatedExpense['company_id'] as int;
      final category = updatedExpense['category'] as String;
      final date = updatedExpense['expense_date'] as String;
      final method = updatedExpense['payment_method'] as String? ?? 'Cash';
      await _reverseAutomatedEntry(
        txn,
        companyId: companyId,
        sourceType: 'expense',
        sourceId: id,
        date: DateTime.now().toIso8601String(),
        reversalDescription: 'REVERSAL: Expense #$id',
      );
      await txn.update('expenses', data, where: 'id = ?', whereArgs: [id]);
      final accounts = await txn.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
      int? accountId(String name) {
        final matches = accounts.where((row) => row['name'].toString().toLowerCase() == name.toLowerCase());
        return matches.isEmpty ? null : matches.first['id'] as int;
      }
      final expenseAccountId = accountId(category) ?? accountId('Operating Expenses');
      final sourceAccountId = accountId(method) ?? accountId('Cash');
      if (expenseAccountId == null || sourceAccountId == null) {
        throw StateError('Expense accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: companyId,
          date: date,
          description: 'Auto: Expense #$id - $category',
          sourceType: 'expense',
          sourceId: id,
          lines: [
            {'account_id': expenseAccountId, 'debit': amount, 'credit': 0.0},
            {'account_id': sourceAccountId, 'debit': 0.0, 'credit': amount},
          ]);
    });
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('expenses', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final expense = rows.first;
      await _reverseAutomatedEntry(
        txn,
        companyId: expense['company_id'] as int,
        sourceType: 'expense',
        sourceId: id,
        date: DateTime.now().toIso8601String(),
        reversalDescription: 'REVERSAL: Expense #$id',
      );
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<double> getTodaysExpensesTotal(int companyId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM expenses WHERE company_id = ? AND substr(expense_date, 1, 10) = ?",
      [companyId, today],
    );
    final value = result.first['total'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  // ---------------- Income helpers ----------------

  Future<int> insertIncome(Map<String, dynamic> data) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final companyId = data['company_id'] as int;
      final amount = _validateLedgerAmount(data['amount'], 'Income');
      final category = data['category'] as String;
      final date = data['income_date'] as String;
      final incomeRecordId = await txn.insert('income', data);
      final accounts = await txn.query(
        'chart_of_accounts',
        where: 'company_id = ?',
        whereArgs: [companyId],
      );
      int? accountId(String name) {
        final matches = accounts.where((row) =>
            row['name'].toString().toLowerCase() == name.toLowerCase());
        return matches.isEmpty ? null : matches.first['id'] as int;
      }

      final cashId = accountId('Cash');
      final incomeAccountId = accountId(category) ?? accountId('Other Income');
      if (cashId == null || incomeAccountId == null) {
        throw StateError('Income accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: companyId,
          date: date,
          description: 'Auto: Income #$incomeRecordId - $category',
          sourceType: 'income',
          sourceId: incomeRecordId,
          lines: [
            {'account_id': cashId, 'debit': amount, 'credit': 0.0},
            {'account_id': incomeAccountId, 'debit': 0.0, 'credit': amount},
          ]);
          return incomeRecordId;
    });
  }

  Future<List<Map<String, dynamic>>> getIncome(int companyId) async {
    final db = await database;
    return db.query('income',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<void> updateIncome(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('income', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final oldIncome = rows.first;
      final updatedIncome = {...oldIncome, ...data};
      final amount = _validateLedgerAmount(updatedIncome['amount'], 'Income');
      final companyId = updatedIncome['company_id'] as int;
      final category = updatedIncome['category'] as String;
      final date = updatedIncome['income_date'] as String;
      await _reverseAutomatedEntry(
        txn,
        companyId: companyId,
        sourceType: 'income',
        sourceId: id,
        date: DateTime.now().toIso8601String(),
        reversalDescription: 'REVERSAL: Income #$id',
      );
      await txn.update('income', data, where: 'id = ?', whereArgs: [id]);
      final cashId = await _findAccountId(txn, companyId, 'Cash');
      final incomeAccountId = await _findAccountId(txn, companyId, category) ??
          await _findAccountId(txn, companyId, 'Other Income');
      if (cashId == null || incomeAccountId == null) {
        throw StateError('Income accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: companyId,
          date: date,
          description: 'Auto: Income #$id - $category',
          sourceType: 'income',
          sourceId: id,
          lines: [
            {'account_id': cashId, 'debit': amount, 'credit': 0.0},
            {'account_id': incomeAccountId, 'debit': 0.0, 'credit': amount},
          ]);
    });
  }

  Future<void> deleteIncome(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('income', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final income = rows.first;
      await _reverseAutomatedEntry(
        txn,
        companyId: income['company_id'] as int,
        sourceType: 'income',
        sourceId: id,
        date: DateTime.now().toIso8601String(),
        reversalDescription: 'REVERSAL: Income #$id',
      );
      await txn.delete('income', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- Customer Ledger helpers ----------------

  /// Records a payment received from a customer and reduces their balance.
  Future<void> insertCustomerPayment(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateLedgerPayment(
        txn,
        companyId: data['company_id'] as int,
        partyTable: 'customers',
        partyId: data['customer_id'],
        amount: data['amount'],
      );
      final payId = await txn.insert('customer_payments', data);
      final companyId = data['company_id'] as int;
      final amount = (data['amount'] as num).toDouble();
      final customerId = data['customer_id'] as int;
      final date = data['payment_date'] as String;
      final method = data['payment_method'] as String? ?? 'Cash';

      await txn.rawUpdate(
        'UPDATE customers SET current_balance = current_balance - ? WHERE id = ?',
        [amount, customerId],
      );

      // Automated Accounting
      final coaRows = await txn.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
      int? getAccId(String name) {
        try { return coaRows.firstWhere((r) => r['name'].toString().toLowerCase() == name.toLowerCase())['id'] as int; } catch(_) { return null; }
      }

      final targetAccId = getAccId(method) ?? getAccId('Cash');
      final recAccId = getAccId('Accounts Receivable');

      if (targetAccId != null && recAccId != null && amount > 0) {
        await postAutomatedEntry(txn,
            companyId: companyId,
            date: date,
            description: 'Auto: Payment Received (Customer ID $customerId)',
            sourceType: 'customer_payment',
            sourceId: payId,
            lines: [
              {'account_id': targetAccId, 'debit': amount, 'credit': 0.0},
              {'account_id': recAccId, 'debit': 0.0, 'credit': amount},
            ]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCustomerPayments(int customerId) async {
    final db = await database;
    return db.query('customer_payments',
        where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'payment_date DESC');
  }

  // ---------------- Supplier Ledger helpers ----------------

  /// Records a payment made to a supplier and reduces their balance.
  Future<void> insertSupplierPayment(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateLedgerPayment(
        txn,
        companyId: data['company_id'] as int,
        partyTable: 'suppliers',
        partyId: data['supplier_id'],
        amount: data['amount'],
      );
      final payId = await txn.insert('supplier_payments', data);
      final companyId = data['company_id'] as int;
      final amount = (data['amount'] as num).toDouble();
      final supplierId = data['supplier_id'] as int;
      final date = data['payment_date'] as String;
      final method = data['payment_method'] as String? ?? 'Cash';

      await txn.rawUpdate(
        'UPDATE suppliers SET current_balance = current_balance - ? WHERE id = ?',
        [amount, supplierId],
      );

      // Automated Accounting
      final coaRows = await txn.query('chart_of_accounts', where: 'company_id = ?', whereArgs: [companyId]);
      int? getAccId(String name) {
        try { return coaRows.firstWhere((r) => r['name'].toString().toLowerCase() == name.toLowerCase())['id'] as int; } catch(_) { return null; }
      }

      final sourceAccId = getAccId(method) ?? getAccId('Cash');
      final payAccId = getAccId('Accounts Payable');

      if (sourceAccId != null && payAccId != null && amount > 0) {
        await postAutomatedEntry(txn,
            companyId: companyId,
            date: date,
            description: 'Auto: Payment Paid (Supplier ID $supplierId)',
            sourceType: 'supplier_payment',
            sourceId: payId,
            lines: [
              {'account_id': payAccId, 'debit': amount, 'credit': 0.0},
              {'account_id': sourceAccId, 'debit': 0.0, 'credit': amount},
            ]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSupplierPayments(int supplierId) async {
    final db = await database;
    return db.query('supplier_payments',
        where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'payment_date DESC');
  }

  // ---------------- Cash Book helpers ----------------

  Future<int> insertCashTransaction(Map<String, dynamic> data) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      _validateCashTransaction(data);
      return txn.insert('cash_transactions', data);
    });
  }

  Future<List<Map<String, dynamic>>> getCashTransactions(int companyId) async {
    final db = await database;
    return db.query('cash_transactions',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'transaction_date DESC, id DESC');
  }

  Future<void> deleteCashTransaction(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('cash_transactions', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      _validateCashTransaction(rows.first);
      await txn.delete('cash_transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- Bank Book helpers ----------------

  Future<int> insertBankAccount(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('bank_accounts', data);
  }

  Future<List<Map<String, dynamic>>> getBankAccounts(int companyId) async {
    final db = await database;
    return db.query('bank_accounts',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'bank_name ASC');
  }

  Future<void> updateBankAccount(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('bank_accounts', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBankAccount(int id) async {
    final db = await database;
    await db.delete('bank_accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertBankTransaction(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final amount = _validateBankTransaction(data);
      final accountRows = await txn.query(
        'bank_accounts',
        columns: ['id'],
        where: 'id = ? AND company_id = ?',
        whereArgs: [data['bank_account_id'], data['company_id']],
        limit: 1,
      );
      if (accountRows.isEmpty) {
        throw ArgumentError('The bank account must belong to the selected company.');
      }
      await txn.insert('bank_transactions', data);
      final delta = (data['type'] == 'deposit')
          ? amount
          : -amount;
      await txn.rawUpdate(
        'UPDATE bank_accounts SET current_balance = current_balance + ? WHERE id = ?',
        [delta, data['bank_account_id']],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getBankTransactions(int bankAccountId) async {
    final db = await database;
    return db.query('bank_transactions',
        where: 'bank_account_id = ?',
        whereArgs: [bankAccountId],
        orderBy: 'transaction_date DESC, id DESC');
  }

  Future<void> deleteBankTransaction(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('bank_transactions', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final transaction = rows.first;
      final amount = _validateBankTransaction(transaction);
      final delta = transaction['type'] == 'deposit' ? -amount : amount;
      await txn.rawUpdate(
        'UPDATE bank_accounts SET current_balance = current_balance + ? WHERE id = ? AND company_id = ?',
        [delta, transaction['bank_account_id'], transaction['company_id']],
      );
      await txn.delete('bank_transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- Reports helpers ----------------
  // All range params are inclusive, ISO date strings ("yyyy-MM-dd").

  Future<List<Map<String, dynamic>>> getSalesBetween(
      int companyId, String fromDate, String toDate) async {
    final db = await database;
    return db.rawQuery('''
      SELECT * FROM sales
      WHERE company_id = ? AND substr(sale_date, 1, 10) BETWEEN ? AND ?
      ORDER BY sale_date DESC
    ''', [companyId, fromDate, toDate]);
  }

  Future<List<Map<String, dynamic>>> getPurchasesBetween(
      int companyId, String fromDate, String toDate) async {
    final db = await database;
    return db.rawQuery('''
      SELECT * FROM purchases
      WHERE company_id = ? AND substr(purchase_date, 1, 10) BETWEEN ? AND ?
      ORDER BY purchase_date DESC
    ''', [companyId, fromDate, toDate]);
  }

  Future<List<Map<String, dynamic>>> getExpensesBetween(
      int companyId, String fromDate, String toDate) async {
    final db = await database;
    return db.rawQuery('''
      SELECT * FROM expenses
      WHERE company_id = ? AND substr(expense_date, 1, 10) BETWEEN ? AND ?
      ORDER BY expense_date DESC
    ''', [companyId, fromDate, toDate]);
  }

  Future<List<Map<String, dynamic>>> getIncomeBetween(
      int companyId, String fromDate, String toDate) async {
    final db = await database;
    return db.rawQuery('''
      SELECT * FROM income
      WHERE company_id = ? AND substr(income_date, 1, 10) BETWEEN ? AND ?
      ORDER BY income_date DESC
    ''', [companyId, fromDate, toDate]);
  }

  /// Gross profit (sum of (unit_price - purchase_price) * quantity) for all
  /// sale_items whose parent sale falls within the given date range.
  Future<double> getProfitBetween(
      int companyId, String fromDate, String toDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM((si.unit_price - si.purchase_price) * si.quantity) as profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.company_id = ? AND substr(s.sale_date, 1, 10) BETWEEN ? AND ?
    ''', [companyId, fromDate, toDate]);
    final value = result.first['profit'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  /// Category-wise expense breakdown within a date range.
  Future<List<Map<String, dynamic>>> getExpenseCategoryBreakdown(
      int companyId, String fromDate, String toDate) async {
    final db = await database;
    return db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM expenses
      WHERE company_id = ? AND substr(expense_date, 1, 10) BETWEEN ? AND ?
      GROUP BY category
      ORDER BY total DESC
    ''', [companyId, fromDate, toDate]);
  }

  /// Total stock valuation (current_stock * purchase_price) across all
  /// products for this company.
  Future<double> getStockValuation(int companyId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(current_stock * purchase_price) as total
      FROM products WHERE company_id = ?
    ''', [companyId]);
    final value = result.first['total'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  /// Customers who currently owe money (Accounts Receivable), highest first.
  Future<List<Map<String, dynamic>>> getReceivables(int companyId) async {
    final db = await database;
    return db.query('customers',
        where: 'company_id = ? AND current_balance > 0',
        whereArgs: [companyId],
        orderBy: 'current_balance DESC');
  }

  /// Suppliers we currently owe money to (Accounts Payable), highest first.
  Future<List<Map<String, dynamic>>> getPayables(int companyId) async {
    final db = await database;
    return db.query('suppliers',
        where: 'company_id = ? AND current_balance > 0',
        whereArgs: [companyId],
        orderBy: 'current_balance DESC');
  }

  // ---------------- Employee helpers ----------------

  Future<int> insertEmployee(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('employees', data);
  }

  Future<List<Map<String, dynamic>>> getEmployees(int companyId,
      {String? searchQuery}) async {
    final db = await database;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      return db.query(
        'employees',
        where: 'company_id = ? AND deleted_at IS NULL AND (name LIKE ? OR designation LIKE ?)',
        whereArgs: [companyId, '%$searchQuery%', '%$searchQuery%'],
        orderBy: 'name ASC',
      );
    }
    return db.query('employees',
        where: 'company_id = ? AND deleted_at IS NULL', whereArgs: [companyId], orderBy: 'name ASC');
  }

  Future<void> updateEmployee(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('employees', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteEmployee(int id) async {
    final db = await database;
    await db.update('employees', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDeletedEmployees(int companyId) async {
    final db = await database;
    return db.query('employees',
        where: 'company_id = ? AND deleted_at IS NOT NULL', whereArgs: [companyId], orderBy: 'deleted_at DESC');
  }

  Future<void> restoreEmployee(int id) async {
    final db = await database;
    await db.update('employees', {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> permanentlyDeleteEmployee(int id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getEmployeeCount(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM employees WHERE company_id = ?', [companyId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------- Attendance helpers ----------------

  /// Marks (or re-marks) attendance for one employee on one date.
  Future<void> markAttendance(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('attendance', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAttendanceForEmployee(
      int employeeId) async {
    final db = await database;
    return db.query('attendance',
        where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getAttendanceForDate(
      int employeeId, String date) async {
    final db = await database;
    final rows = await db.query('attendance',
        where: 'employee_id = ? AND date = ?', whereArgs: [employeeId, date]);
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------- Salary helpers ----------------

  Future<void> insertSalaryPayment(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateEmployeeAmount(txn, data, 'amount', 'Salary');
      await txn.insert('salary_payments', data);
    });
  }

  Future<List<Map<String, dynamic>>> getSalaryPayments(int employeeId) async {
    final db = await database;
    return db.query('salary_payments',
        where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'payment_date DESC');
  }

  // ---------------- Advance Salary helpers ----------------

  Future<void> insertAdvance(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateEmployeeAmount(txn, data, 'amount', 'Advance');
      final recovered = (data['recovered_amount'] as num?)?.toDouble() ?? 0;
      if (!recovered.isFinite || recovered < 0) {
        throw ArgumentError('Recovered advance amount is invalid.');
      }
      await txn.insert('advance_salary', data);
    });
  }

  Future<List<Map<String, dynamic>>> getAdvances(int employeeId) async {
    final db = await database;
    return db.query('advance_salary',
        where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'advance_date DESC');
  }

  /// Records a recovery against a pending advance and updates its status.
  Future<void> recoverAdvance(int advanceId, double recoveryAmount) async {
    final db = await database;
    await db.transaction((txn) async {
      if (!recoveryAmount.isFinite || recoveryAmount <= 0) {
        throw ArgumentError('Recovery amount must be positive and finite.');
      }
      final rows = await txn.query('advance_salary', where: 'id = ?', whereArgs: [advanceId]);
      if (rows.isEmpty) return;
      final advance = rows.first;
      final recovered = (advance['recovered_amount'] as num).toDouble();
      final total = (advance['amount'] as num).toDouble();
      if (recovered < 0 || total <= 0 || recovered + recoveryAmount > total) {
        throw ArgumentError('Recovery cannot exceed the outstanding advance.');
      }
      final newRecovered = recovered + recoveryAmount;
      await txn.update(
        'advance_salary',
        {
          'recovered_amount': newRecovered,
          'status': newRecovered >= total ? 'recovered' : 'pending',
        },
        where: 'id = ?',
        whereArgs: [advanceId],
      );
    });
  }

  // ---------------- Commission helpers ----------------

  Future<void> insertCommission(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateEmployeeAmount(txn, data, 'amount', 'Commission');
      await txn.insert('commissions', data);
    });
  }

  Future<List<Map<String, dynamic>>> getCommissions(int employeeId) async {
    final db = await database;
    return db.query('commissions',
        where: 'employee_id = ?', whereArgs: [employeeId], orderBy: 'commission_date DESC');
  }

  // ---------------- Committee helpers ----------------

  Future<int> insertCommittee(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('committees', data);
  }

  Future<List<Map<String, dynamic>>> getCommittees(int companyId) async {
    final db = await database;
    return db.query('committees',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<void> updateCommittee(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('committees', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCommittee(int id) async {
    final db = await database;
    await db.delete('committees', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertCommitteeMember(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('committee_members', data);
  }

  Future<List<Map<String, dynamic>>> getCommitteeMembers(int committeeId) async {
    final db = await database;
    return db.query('committee_members',
        where: 'committee_id = ?', whereArgs: [committeeId], orderBy: 'id ASC');
  }

  Future<void> deleteCommitteeMember(int id) async {
    final db = await database;
    await db.delete('committee_members', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markMemberDrawn(int memberId, bool drawn) async {
    final db = await database;
    await db.update('committee_members', {'has_drawn': drawn ? 1 : 0},
        where: 'id = ?', whereArgs: [memberId]);
  }

  Future<void> insertCommitteeInstallment(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateCommitteeMember(txn, data);
      _validateLedgerAmount(data['amount'], 'Committee installment');
      await txn.insert('committee_installments', data);
    });
  }

  Future<List<Map<String, dynamic>>> getCommitteeInstallments(
      int committeeId) async {
    final db = await database;
    return db.query('committee_installments',
        where: 'committee_id = ?', whereArgs: [committeeId], orderBy: 'payment_date DESC');
  }

  Future<void> insertCommitteeDraw(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await _validateCommitteeMember(txn, data);
      _validateLedgerAmount(data['amount'], 'Committee draw');
      await txn.insert('committee_draws', data);
      final updated = await txn.update(
        'committee_members',
        {'has_drawn': 1},
        where: 'id = ? AND has_drawn = 0',
        whereArgs: [data['member_id']],
      );
      if (updated != 1) {
        throw StateError('This committee member has already received a draw.');
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCommitteeDraws(int committeeId) async {
    final db = await database;
    return db.query('committee_draws',
        where: 'committee_id = ?', whereArgs: [committeeId], orderBy: 'draw_date DESC');
  }

  // ---------------- Cheque helpers ----------------

  Future<int> insertCheque(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('cheques', data);
  }

  Future<List<Map<String, dynamic>>> getCheques(int companyId,
      {required String type}) async {
    final db = await database;
    return db.query('cheques',
        where: 'company_id = ? AND type = ?',
        whereArgs: [companyId, type],
        orderBy: 'cheque_date DESC');
  }

  Future<void> updateChequeStatus(int id, String status) async {
    final db = await database;
    await db.update('cheques', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCheque(int id) async {
    final db = await database;
    await db.delete('cheques', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Sales Return helpers ----------------

  Future<String> generateSalesReturnNumber(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM sales_returns WHERE company_id = ?', [companyId]);
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return 'SR-${count.toString().padLeft(6, '0')}';
  }

  /// Saves a sales return + its items, increases stock for each returned
  /// product, and (if a customer is linked) reduces their current_balance
  /// by the refund total — this credits them, whether it clears part of a
  /// due balance or puts them in credit.
  Future<int> insertSalesReturnWithItems({
    required Map<String, dynamic> salesReturn,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      await _validateSalesReturnItems(txn, salesReturn, items);
      await _validateInventoryItems(
        txn,
        salesReturn['company_id'] as int,
        items,
        priceKey: 'unit_price',
      );
      final returnId = await txn.insert('sales_returns', salesReturn);

      for (final item in items) {
        await txn.insert('sales_return_items', {
          ...item,
          'return_id': returnId,
        });

        final productId = item['product_id'] as int?;
        final qty = item['quantity'] as num;
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [qty, productId],
          );
        }
      }

      final customerId = salesReturn['customer_id'] as int?;
      final total = salesReturn['total_amount'] as num;
      if (customerId != null &&
          salesReturn['refund_method'] == 'adjust_due' &&
          total > 0) {
        await txn.rawUpdate(
          'UPDATE customers SET current_balance = current_balance - ? WHERE id = ?',
          [total, customerId],
        );
      }

      final cashId = await _findAccountId(txn, salesReturn['company_id'] as int, 'Cash');
      final receivableId = await _findAccountId(txn, salesReturn['company_id'] as int, 'Accounts Receivable');
      final revenueId = await _findAccountId(txn, salesReturn['company_id'] as int, 'Sales Revenue');
      final refundAccountId = salesReturn['refund_method'] == 'adjust_due' ? receivableId : cashId;
      final totalAmount = _validateLedgerAmount(salesReturn['total_amount'], 'Sales return');
      if (refundAccountId == null || revenueId == null) {
        throw StateError('Sales return accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: salesReturn['company_id'] as int,
          date: salesReturn['return_date'] as String,
          description: 'Auto: Sales Return ${salesReturn['return_number']}',
          sourceType: 'sales_return',
          sourceId: returnId,
          lines: [
            {'account_id': revenueId, 'debit': totalAmount, 'credit': 0.0},
            {'account_id': refundAccountId, 'debit': 0.0, 'credit': totalAmount},
          ]);

      return returnId;
    });
  }

  Future<List<Map<String, dynamic>>> getSalesReturns(int companyId) async {
    final db = await database;
    return db.query('sales_returns',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getSalesReturnItems(int returnId) async {
    final db = await database;
    return db.query('sales_return_items',
        where: 'return_id = ?', whereArgs: [returnId]);
  }

  // ---------------- Purchase Return helpers ----------------

  Future<String> generatePurchaseReturnNumber(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM purchase_returns WHERE company_id = ?', [companyId]);
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return 'PR-${count.toString().padLeft(6, '0')}';
  }

  /// Saves a purchase return + its items, decreases stock for each returned
  /// product, and (if a supplier is linked) reduces their current_balance —
  /// what we owe them goes down.
  Future<int> insertPurchaseReturnWithItems({
    required Map<String, dynamic> purchaseReturn,
    required List<Map<String, dynamic>> items,
    bool allowNegativeStock = true,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      await _validatePurchaseReturnItems(txn, purchaseReturn, items);
      await _validateInventoryItems(
        txn,
        purchaseReturn['company_id'] as int,
        items,
        priceKey: 'unit_cost',
        allowNegativeStock: allowNegativeStock,
      );
      final returnId = await txn.insert('purchase_returns', purchaseReturn);

      for (final item in items) {
        await txn.insert('purchase_return_items', {
          ...item,
          'return_id': returnId,
        });

        final productId = item['product_id'] as int?;
        final qty = item['quantity'] as num;
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [qty, productId],
          );
        }
      }

      final supplierId = purchaseReturn['supplier_id'] as int?;
      final total = purchaseReturn['total_amount'] as num;
      if (supplierId != null && total > 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET current_balance = current_balance - ? WHERE id = ?',
          [total, supplierId],
        );
      }

      final cashId = await _findAccountId(txn, purchaseReturn['company_id'] as int, 'Cash');
      final payableId = await _findAccountId(txn, purchaseReturn['company_id'] as int, 'Accounts Payable');
      final inventoryId = await _findAccountId(txn, purchaseReturn['company_id'] as int, 'Inventory');
      final settlementAccountId = cashId ?? payableId;
      final totalAmount = _validateLedgerAmount(purchaseReturn['total_amount'], 'Purchase return');
      if (settlementAccountId == null || inventoryId == null) {
        throw StateError('Purchase return accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: purchaseReturn['company_id'] as int,
          date: purchaseReturn['return_date'] as String,
          description: 'Auto: Purchase Return ${purchaseReturn['return_number']}',
          sourceType: 'purchase_return',
          sourceId: returnId,
          lines: [
            {'account_id': settlementAccountId, 'debit': totalAmount, 'credit': 0.0},
            {'account_id': inventoryId, 'debit': 0.0, 'credit': totalAmount},
          ]);

      return returnId;
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturns(int companyId) async {
    final db = await database;
    return db.query('purchase_returns',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturnItems(int returnId) async {
    final db = await database;
    return db.query('purchase_return_items',
        where: 'return_id = ?', whereArgs: [returnId]);
  }

  // ---------------- Delivery Challan helpers ----------------

  Future<String> generateChallanNumber(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM delivery_challans WHERE company_id = ?', [companyId]);
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return 'DC-${count.toString().padLeft(6, '0')}';
  }

  Future<int> insertChallanWithItems({
    required Map<String, dynamic> challan,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final challanId = await txn.insert('delivery_challans', challan);
      for (final item in items) {
        await txn.insert('delivery_challan_items', {
          ...item,
          'challan_id': challanId,
        });
      }
      return challanId;
    });
  }

  Future<List<Map<String, dynamic>>> getChallans(int companyId) async {
    final db = await database;
    return db.query('delivery_challans',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getChallanItems(int challanId) async {
    final db = await database;
    return db.query('delivery_challan_items',
        where: 'challan_id = ?', whereArgs: [challanId]);
  }

  Future<void> updateChallanStatus(int id, String status) async {
    final db = await database;
    await db.update('delivery_challans', {'delivery_status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateChallanSignature(int id, String signaturePath) async {
    final db = await database;
    await db.update('delivery_challans', {'signature_path': signaturePath},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Purchase Order helpers ----------------

  Future<String> generatePoNumber(int companyId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM purchase_orders WHERE company_id = ?', [companyId]);
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return 'PO-${count.toString().padLeft(6, '0')}';
  }

  Future<int> insertPurchaseOrderWithItems({
    required Map<String, dynamic> po,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final poId = await txn.insert('purchase_orders', po);
      for (final item in items) {
        await txn.insert('purchase_order_items', {
          ...item,
          'po_id': poId,
        });
      }
      return poId;
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders(int companyId) async {
    final db = await database;
    return db.query('purchase_orders',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderItems(int poId) async {
    final db = await database;
    return db.query('purchase_order_items', where: 'po_id = ?', whereArgs: [poId]);
  }

  Future<void> updatePurchaseOrderStatus(int id, String status) async {
    final db = await database;
    await db.update('purchase_orders', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePurchaseOrder(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('purchase_order_items', where: 'po_id = ?', whereArgs: [id]);
      await txn.delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- Audit Log helpers ----------------

  Future<void> insertAuditLog(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('audit_log', data);
  }

  Future<List<Map<String, dynamic>>> getAuditLogs(
    int companyId, {
    String? module,
    String? action,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await database;
    final where = StringBuffer('company_id = ?');
    final args = <Object?>[companyId];

    if (module != null && module.isNotEmpty) {
      where.write(' AND module = ?');
      args.add(module);
    }
    if (action != null && action.isNotEmpty) {
      where.write(' AND action = ?');
      args.add(action);
    }
    if (fromDate != null && toDate != null) {
      where.write(' AND substr(timestamp, 1, 10) BETWEEN ? AND ?');
      args.add(fromDate);
      args.add(toDate);
    }

    return db.query('audit_log',
        where: where.toString(), whereArgs: args, orderBy: 'id DESC', limit: 500);
  }

  // ---------------- Inventory Adjustment helpers ----------------

  Future<void> insertStockAdjustment(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final quantity = _validateLedgerAmount(data['quantity'], 'Stock adjustment');
      final productId = data['product_id'];
      final companyId = data['company_id'];
        if (productId is! int || companyId is! int ||
          !const {'increase', 'decrease', 'damage', 'lost'}
            .contains(data['type'])) {
        throw ArgumentError('Stock adjustment details are invalid.');
      }
      final products = await txn.query('products',
          columns: ['purchase_price'],
          where: 'id = ? AND company_id = ?',
          whereArgs: [productId, companyId],
          limit: 1);
      if (products.isEmpty) {
        throw ArgumentError('The adjusted product must belong to the selected company.');
      }
      final adjId = await txn.insert('stock_adjustments', data);
      final type = data['type'] as String;
      final delta = type == 'increase' ? quantity : -quantity;
      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
        [delta, data['product_id']],
      );
      final value = quantity * (products.first['purchase_price'] as num).toDouble();
      await _ensureChartOfAccountsInTransaction(txn, companyId);
      final inventoryId = await _findAccountId(txn, companyId, 'Inventory');
      final offsetName = type == 'increase' ? 'Other Income' : 'Operating Expenses';
      final offsetId = await _findAccountId(txn, companyId, offsetName);
      if (inventoryId == null || offsetId == null || value <= 0) {
        throw StateError('Stock adjustment accounts are not configured.');
      }
      await postAutomatedEntry(txn,
          companyId: companyId,
          date: data['adjustment_date'] as String,
          description: 'Auto: Stock Adjustment ${data['product_name']}',
          sourceType: 'stock_adjustment',
          sourceId: adjId,
          lines: type == 'increase'
              ? [
                  {'account_id': inventoryId, 'debit': value, 'credit': 0.0},
                  {'account_id': offsetId, 'debit': 0.0, 'credit': value},
                ]
              : [
                  {'account_id': offsetId, 'debit': value, 'credit': 0.0},
                  {'account_id': inventoryId, 'debit': 0.0, 'credit': value},
                ]);
    });
  }

  Future<List<Map<String, dynamic>>> getStockAdjustments(int companyId) async {
    final db = await database;
    return db.query('stock_adjustments',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id DESC');
  }

  // ---------------- Journal / Chart of Accounts helpers ----------------

  static const List<Map<String, String>> defaultChartOfAccounts = [
    {'code': '1001', 'name': 'Cash', 'type': 'asset'},
    {'code': '1002', 'name': 'Bank', 'type': 'asset'},
    {'code': '1003', 'name': 'Accounts Receivable', 'type': 'asset'},
    {'code': '1004', 'name': 'Inventory', 'type': 'asset'},
    {'code': '1005', 'name': 'Fixed Assets', 'type': 'asset'},
    {'code': '2001', 'name': 'Accounts Payable', 'type': 'liability'},
    {'code': '2002', 'name': 'Loans', 'type': 'liability'},
    {'code': '2003', 'name': 'Salaries Payable', 'type': 'liability'},
    {'code': '2004', 'name': 'Taxes Payable', 'type': 'liability'},
    {'code': '3001', 'name': "Owner's Capital", 'type': 'equity'},
    {'code': '3002', 'name': "Owner's Drawings", 'type': 'equity'},
    {'code': '3003', 'name': 'Retained Earnings', 'type': 'equity'},
    {'code': '4001', 'name': 'Sales Revenue', 'type': 'income'},
    {'code': '4002', 'name': 'Other Income', 'type': 'income'},
    {'code': '5001', 'name': 'Cost of Goods Sold', 'type': 'expense'},
    {'code': '5002', 'name': 'Operating Expenses', 'type': 'expense'},
    {'code': '5003', 'name': 'Rent', 'type': 'expense'},
    {'code': '5004', 'name': 'Electricity', 'type': 'expense'},
    {'code': '5005', 'name': 'Salaries', 'type': 'expense'},
    {'code': '5006', 'name': 'Taxes', 'type': 'expense'},
    {'code': '5007', 'name': 'Transport', 'type': 'expense'},
  ];

  Future<List<Map<String, dynamic>>> getChartOfAccounts(int companyId) async {
    final db = await database;
    return db.query('chart_of_accounts',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'code ASC');
  }

  /// Creates the default chart of accounts for a company if it doesn't
  /// have any accounts yet. Safe to call every time the Journal screen
  /// opens — it only seeds once.
  Future<void> ensureChartOfAccounts(int companyId) async {
    final existing = await getChartOfAccounts(companyId);
    if (existing.isNotEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final acc in defaultChartOfAccounts) {
      batch.insert('chart_of_accounts', {
        'company_id': companyId,
        'code': acc['code'],
        'name': acc['name'],
        'type': acc['type'],
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _ensureChartOfAccountsInTransaction(
      Transaction txn, int companyId) async {
    final existing = await txn.query(
      'chart_of_accounts',
      columns: ['id'],
      where: 'company_id = ?',
      whereArgs: [companyId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    for (final account in defaultChartOfAccounts) {
      await txn.insert('chart_of_accounts', {
        'company_id': companyId,
        'code': account['code'],
        'name': account['name'],
        'type': account['type'],
        'created_at': now,
      });
    }
  }

  Future<int> insertJournalEntryWithLines({
    required Map<String, dynamic> entry,
    required List<Map<String, dynamic>> lines,
  }) async {
    _validateJournalLines(lines);
    final db = await database;
    return db.transaction<int>((txn) async {
      await _validateJournalAccounts(
        txn,
        entry['company_id'] as int,
        lines,
      );
      final entryId = await txn.insert('journal_entries', entry);
      for (final line in lines) {
        await txn.insert('journal_entry_lines', {...line, 'journal_entry_id': entryId});
      }
      return entryId;
    });
  }

  Future<List<Map<String, dynamic>>> getJournalEntries(int companyId) async {
    final db = await database;
    return db.query('journal_entries',
        where: 'company_id = ?', whereArgs: [companyId], orderBy: 'entry_date DESC, id DESC');
  }

  Future<List<Map<String, dynamic>>> getJournalEntryLines(int journalEntryId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT jel.*, coa.name as account_name, coa.code as account_code
      FROM journal_entry_lines jel
      INNER JOIN chart_of_accounts coa ON coa.id = jel.account_id
      WHERE jel.journal_entry_id = ?
    ''', [journalEntryId]);
  }

  Future<void> deleteJournalEntry(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('journal_entry_lines', where: 'journal_entry_id = ?', whereArgs: [id]);
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Trial balance: for each account, total debit and total credit across
  /// all journal entries (optionally within a date range).
  Future<List<Map<String, dynamic>>> getTrialBalance(int companyId,
      {String? fromDate, String? toDate}) async {
    final db = await database;
    final where = StringBuffer('coa.company_id = ?');
    final args = <Object?>[companyId];
    if (fromDate != null && toDate != null) {
      where.write(' AND substr(je.entry_date, 1, 10) BETWEEN ? AND ?');
      args.add(fromDate);
      args.add(toDate);
    }
    return db.rawQuery('''
      SELECT coa.id, coa.code, coa.name, coa.type,
             COALESCE(SUM(jel.debit), 0) as total_debit,
             COALESCE(SUM(jel.credit), 0) as total_credit
      FROM chart_of_accounts coa
      LEFT JOIN journal_entry_lines jel ON jel.account_id = coa.id
      LEFT JOIN journal_entries je ON je.id = jel.journal_entry_id
      WHERE $where
      GROUP BY coa.id
      ORDER BY coa.code ASC
    ''', args);
  }

  // ---------------- Staff / Roles helpers ----------------

  Future<int> insertStaffUser(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('staff_users', data);
  }

  Future<List<Map<String, dynamic>>> getStaffUsers(int companyId) async {
    final db = await database;
    return db.query('staff_users', where: 'company_id = ?', whereArgs: [companyId], orderBy: 'name ASC');
  }

  Future<void> deleteStaffUser(int id) async {
    final db = await database;
    await db.delete('staff_users', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStaffUser(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('staff_users', data, where: 'id = ?', whereArgs: [id]);
  }

  /// Checks a PIN against every staff user for a company (cashier PINs are
  /// per-company since a device may hold multiple shops).
  Future<Map<String, dynamic>?> findStaffUserByCompany(int companyId) async {
    final db = await database;
    final rows = await db.query('staff_users', where: 'company_id = ?', whereArgs: [companyId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllStaffUsersAcrossCompanies() async {
    final db = await database;
    return db.query('staff_users');
  }

  // ---------------- Duplicate barcode check ----------------

  Future<bool> isBarcodeTaken(int companyId, String barcode, {int? excludingProductId}) async {
    if (barcode.trim().isEmpty) return false;
    final db = await database;
    final where = StringBuffer('company_id = ? AND deleted_at IS NULL AND barcode = ?');
    final args = <Object?>[companyId, barcode.trim()];
    if (excludingProductId != null) {
      where.write(' AND id != ?');
      args.add(excludingProductId);
    }
    final rows = await db.query('products', where: where.toString(), whereArgs: args);
    return rows.isNotEmpty;
  }

  /// Permanently deletes a company and every record that belongs to it.
  /// This cannot be undone — the caller must confirm with the user first.
  Future<void> deleteCompanyPermanently(int companyId) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Line/child tables that hang off a parent row (Foreign Key children)
      await txn.rawDelete(
          'DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM purchase_items WHERE purchase_id IN (SELECT id FROM purchases WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM sales_return_items WHERE return_id IN (SELECT id FROM sales_returns WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM purchase_return_items WHERE return_id IN (SELECT id FROM purchase_returns WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM delivery_challan_items WHERE challan_id IN (SELECT id FROM delivery_challans WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM purchase_order_items WHERE po_id IN (SELECT id FROM purchase_orders WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM journal_entry_lines WHERE journal_entry_id IN (SELECT id FROM journal_entries WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM bank_transactions WHERE bank_account_id IN (SELECT id FROM bank_accounts WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM committee_installments WHERE committee_id IN (SELECT id FROM committees WHERE company_id = ?)',
          [companyId]);
      await txn.rawDelete(
          'DELETE FROM committee_draws WHERE committee_id IN (SELECT id FROM committees WHERE company_id = ?)',
          [companyId]);
        await txn.rawDelete(
          'DELETE FROM committee_members WHERE committee_id IN (SELECT id FROM committees WHERE company_id = ?)',
          [companyId]);

      // 2. Secondary tables with company_id (Children of main masters)
      const secondaryTables = [
        'audit_log', 'attendance', 'salary_payments', 'advance_salary',
        'commissions', 'customer_payments', 'supplier_payments',
        'cash_transactions', 'stock_adjustments', 'journal_entries'
      ];
      for (final table in secondaryTables) {
        await txn.delete(table, where: 'company_id = ?', whereArgs: [companyId]);
      }

      // 3. Main Transactional/Entity tables
      const mainTables = [
        'sales', 'purchases', 'sales_returns', 'purchase_returns',
        'delivery_challans', 'purchase_orders', 'bank_accounts',
        'committees', 'employees', 'cheques', 'products'
      ];
      for (final table in mainTables) {
        await txn.delete(table, where: 'company_id = ?', whereArgs: [companyId]);
      }

      // 4. Master tables (Categories, Brands, Chart of Accounts, etc.)
      const masterTables = [
        'categories', 'brands', 'customers', 'suppliers', 'chart_of_accounts',
        'expenses', 'income', 'staff_users'
      ];
      for (final table in masterTables) {
        await txn.delete(table, where: 'company_id = ?', whereArgs: [companyId]);
      }

      // 5. Finally, delete the company itself
      await txn.delete('companies', where: 'id = ?', whereArgs: [companyId]);
    });
  }

  // ---------------- Accounting Engine helpers ----------------

  Future<int?> getAccountIdByName(int companyId, String name) async {
    final db = await database;
    final rows = await db.query('chart_of_accounts',
        where: 'company_id = ? AND name = ?',
        whereArgs: [companyId, name],
        limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  /// Posts an automated journal entry into the system.
  Future<void> postAutomatedEntry(Transaction txn, {
    required int companyId,
    required String date,
    required String description,
    required List<Map<String, dynamic>> lines,
    String? sourceType,
    int? sourceId,
  }) async {
    _validateJournalLines(lines);
    await _validateJournalAccounts(txn, companyId, lines);

    final entryId = await txn.insert('journal_entries', {
      'company_id': companyId,
      'entry_date': date,
      'description': description,
      'source_type': sourceType,
      'source_id': sourceId,
      'created_at': DateTime.now().toIso8601String(),
    });

    for (final line in lines) {
      await txn.insert('journal_entry_lines', {
        ...line,
        'journal_entry_id': entryId,
      });
    }
  }

  void _validateJournalLines(List<Map<String, dynamic>> lines) {
    if (lines.length < 2) {
      throw ArgumentError('A journal entry must contain at least two lines.');
    }

    var totalDebit = 0.0;
    var totalCredit = 0.0;
    for (final line in lines) {
      final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;
      final accountId = line['account_id'];

      if (accountId is! int ||
          !debit.isFinite ||
          !credit.isFinite ||
          debit < 0 ||
          credit < 0 ||
          (debit > 0 && credit > 0) ||
          (debit == 0 && credit == 0)) {
        throw ArgumentError('Each journal line must have one positive debit or credit.');
      }
      totalDebit += debit;
      totalCredit += credit;
    }

    if (totalDebit <= 0 || (totalDebit - totalCredit).abs() >= 0.01) {
      throw ArgumentError('Journal debits and credits must balance.');
    }
  }

  Future<void> _validateJournalAccounts(
    Transaction txn,
    int companyId,
    List<Map<String, dynamic>> lines,
  ) async {
    final accountIds = lines.map((line) => line['account_id'] as int).toSet();
    final accounts = await txn.query(
      'chart_of_accounts',
      columns: ['id'],
      where: 'company_id = ? AND id IN (${List.filled(accountIds.length, '?').join(',')})',
      whereArgs: [companyId, ...accountIds],
    );
    if (accounts.length != accountIds.length) {
      throw ArgumentError('Every journal account must belong to the selected company.');
    }
  }

  Future<void> _validateInventoryItems(
    Transaction txn,
    int companyId,
    List<Map<String, dynamic>> items, {
    required String priceKey,
    bool allowNegativeStock = true,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('A transaction must contain at least one item.');
    }

    final productIds = <int>{};
    final Map<int, double> requestedQtys = {};
    for (final item in items) {
      final quantity = (item['quantity'] as num?)?.toDouble();
      final price = (item[priceKey] as num?)?.toDouble();
      final productId = item['product_id'];
      if (quantity == null || !quantity.isFinite || quantity <= 0 ||
          price == null || !price.isFinite || price < 0) {
        throw ArgumentError('Each inventory item must have a valid quantity and price.');
      }
      if (productId != null) {
        if (productId is! int) {
          throw ArgumentError('Inventory product IDs must be integers.');
        }
        productIds.add(productId);
        requestedQtys[productId] = (requestedQtys[productId] ?? 0) + quantity;
      }
    }

    if (productIds.isEmpty) return;
    final products = await txn.query(
      'products',
      columns: ['id', 'name', 'current_stock'],
      where: 'company_id = ? AND id IN (${List.filled(productIds.length, '?').join(',')})',
      whereArgs: [companyId, ...productIds],
    );
    if (products.length != productIds.length) {
      throw ArgumentError('Every inventory product must belong to the selected company.');
    }

    if (!allowNegativeStock) {
      for (final p in products) {
        final id = p['id'] as int;
        final stock = (p['current_stock'] as num).toDouble();
        final requested = requestedQtys[id]!;
        if (requested > stock) {
          throw StateError('Stock kam hai: ${p['name']} (Available: $stock, Requested: $requested)');
        }
      }
    }
  }

  Future<void> _validateLedgerPayment(
    Transaction txn, {
    required int companyId,
    required String partyTable,
    required Object? partyId,
    required Object? amount,
  }) async {
    final numericAmount = (amount as num?)?.toDouble();
    if (numericAmount == null || !numericAmount.isFinite || numericAmount <= 0) {
      throw ArgumentError('Payment amount must be a positive finite number.');
    }
    if (partyId is! int) {
      throw ArgumentError('A valid ledger party is required for a payment.');
    }

    final rows = await txn.query(
      partyTable,
      columns: ['id'],
      where: 'id = ? AND company_id = ?',
      whereArgs: [partyId, companyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ArgumentError('The ledger party must belong to the selected company.');
    }
  }

  void _validateCashTransaction(Map<String, dynamic> data) {
    final amount = (data['amount'] as num?)?.toDouble();
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw ArgumentError('Cash amount must be a positive finite number.');
    }
    if (data['type'] != 'in' && data['type'] != 'out') {
      throw ArgumentError('Cash transaction type must be in or out.');
    }
  }

  double _validateBankTransaction(Map<String, dynamic> data) {
    final amount = (data['amount'] as num?)?.toDouble();
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw ArgumentError('Bank amount must be a positive finite number.');
    }
    if (data['type'] != 'deposit' && data['type'] != 'withdrawal') {
      throw ArgumentError('Bank transaction type is invalid.');
    }
    if (data['bank_account_id'] is! int || data['company_id'] is! int) {
      throw ArgumentError('A valid company and bank account are required.');
    }
    return amount;
  }

  double _validateLedgerAmount(Object? value, String label) {
    final amount = (value as num?)?.toDouble();
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw ArgumentError('$label amount must be a positive finite number.');
    }
    return amount;
  }

  Future<void> _validateEmployeeAmount(
    Transaction txn,
    Map<String, dynamic> data,
    String amountKey,
    String label,
  ) async {
    _validateLedgerAmount(data[amountKey], label);
    final employeeId = data['employee_id'];
    final companyId = data['company_id'];
    if (employeeId is! int || companyId is! int) {
      throw ArgumentError('A valid company and employee are required.');
    }
    final rows = await txn.query(
      'employees',
      columns: ['id'],
      where: 'id = ? AND company_id = ?',
      whereArgs: [employeeId, companyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ArgumentError('The employee must belong to the selected company.');
    }
  }

  Future<void> _validateCommitteeMember(
    Transaction txn,
    Map<String, dynamic> data,
  ) async {
    final companyId = data['company_id'];
    final committeeId = data['committee_id'];
    final memberId = data['member_id'];
    if (companyId is! int || committeeId is! int || memberId is! int) {
      throw ArgumentError('A valid company, committee, and member are required.');
    }
    final rows = await txn.rawQuery('''
      SELECT cm.id
      FROM committee_members cm
      INNER JOIN committees c ON c.id = cm.committee_id
      WHERE cm.id = ? AND cm.committee_id = ? AND c.company_id = ?
    ''', [memberId, committeeId, companyId]);
    if (rows.isEmpty) {
      throw ArgumentError('The committee member must belong to the selected committee.');
    }
  }

  Future<int?> _findAccountId(Transaction txn, int companyId, String name) async {
    final rows = await txn.query(
      'chart_of_accounts',
      columns: ['id'],
      where: 'company_id = ? AND name = ?',
      whereArgs: [companyId, name],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<void> _reverseAutomatedEntry(
    Transaction txn, {
    required int companyId,
    required String sourceType,
    required int sourceId,
    required String date,
    required String reversalDescription,
  }) async {
    final entries = await txn.query(
      'journal_entries',
      where: 'company_id = ? AND source_type = ? AND source_id = ?',
      whereArgs: [companyId, sourceType, sourceId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (entries.isEmpty) return;
    final lines = await txn.query(
      'journal_entry_lines',
      where: 'journal_entry_id = ?',
      whereArgs: [entries.first['id']],
    );
    final reversalLines = lines
        .map((line) => {
              'account_id': line['account_id'],
              'debit': line['credit'],
              'credit': line['debit'],
            })
        .toList();
    await postAutomatedEntry(
      txn,
      companyId: companyId,
      date: date,
      description: reversalDescription,
      sourceType: 'reversal',
      sourceId: entries.first['id'] as int,
      lines: reversalLines,
    );
  }

  Future<void> _validateSalesReturnItems(
    Transaction txn,
    Map<String, dynamic> salesReturn,
    List<Map<String, dynamic>> items,
  ) async {
    final saleId = salesReturn['sale_id'];
    final companyId = salesReturn['company_id'];
    if (saleId is! int || companyId is! int) {
      throw ArgumentError('A valid sale and company are required for a return.');
    }
    final saleRows = await txn.query('sales',
        columns: ['id'], where: 'id = ? AND company_id = ?', whereArgs: [saleId, companyId], limit: 1);
    if (saleRows.isEmpty) throw ArgumentError('The sale must belong to the selected company.');
    final original = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    final returned = await txn.rawQuery('''
      SELECT sri.product_id, COALESCE(SUM(sri.quantity), 0) AS quantity
      FROM sales_return_items sri
      INNER JOIN sales_returns sr ON sr.id = sri.return_id
      WHERE sr.sale_id = ?
      GROUP BY sri.product_id
    ''', [saleId]);
    await _validateReturnQuantities(items, original, returned, 'Sales return');
  }

  Future<void> _validatePurchaseReturnItems(
    Transaction txn,
    Map<String, dynamic> purchaseReturn,
    List<Map<String, dynamic>> items,
  ) async {
    final purchaseId = purchaseReturn['purchase_id'];
    final companyId = purchaseReturn['company_id'];
    if (purchaseId is! int || companyId is! int) {
      throw ArgumentError('A valid purchase and company are required for a return.');
    }
    final purchaseRows = await txn.query('purchases',
        columns: ['id'], where: 'id = ? AND company_id = ?', whereArgs: [purchaseId, companyId], limit: 1);
    if (purchaseRows.isEmpty) throw ArgumentError('The purchase must belong to the selected company.');
    final original = await txn.query('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
    final returned = await txn.rawQuery('''
      SELECT pri.product_id, COALESCE(SUM(pri.quantity), 0) AS quantity
      FROM purchase_return_items pri
      INNER JOIN purchase_returns pr ON pr.id = pri.return_id
      WHERE pr.purchase_id = ?
      GROUP BY pri.product_id
    ''', [purchaseId]);
    await _validateReturnQuantities(items, original, returned, 'Purchase return');
  }

  Future<void> _validateReturnQuantities(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> original,
    List<Map<String, dynamic>> returned,
    String label,
  ) async {
    final originalByProduct = <int, double>{};
    for (final row in original) {
      final productId = row['product_id'];
      if (productId is int) {
        originalByProduct[productId] =
            (originalByProduct[productId] ?? 0) + (row['quantity'] as num).toDouble();
      }
    }
    final returnedByProduct = <int, double>{};
    for (final row in returned) {
      final productId = row['product_id'];
      if (productId is int) returnedByProduct[productId] = (row['quantity'] as num).toDouble();
    }
    for (final item in items) {
      final productId = item['product_id'];
      final quantity = (item['quantity'] as num?)?.toDouble();
      if (productId is! int || quantity == null || !quantity.isFinite || quantity <= 0) {
        throw ArgumentError('$label item is invalid.');
      }
      final available = (originalByProduct[productId] ?? 0) - (returnedByProduct[productId] ?? 0);
      if (quantity > available + 0.000001) {
        throw ArgumentError('$label quantity exceeds the available original quantity.');
      }
    }
  }
}
