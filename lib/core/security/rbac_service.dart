import 'dart:convert';
import '../database/db_helper.dart';

/// All discrete permissions in the app. Each maps to a specific capability
/// that can be independently granted or revoked per role.
abstract class Permissions {
  static const viewDashboard    = 'view_dashboard';
  static const viewReports      = 'view_reports';
  static const viewProducts     = 'view_products';
  static const editProducts     = 'edit_products';
  static const deleteProducts   = 'delete_products';
  static const viewCustomers    = 'view_customers';
  static const editCustomers    = 'edit_customers';
  static const deleteCustomers  = 'delete_customers';
  static const createSale       = 'create_sale';
  static const voidSale         = 'void_sale';
  static const applyDiscount    = 'apply_discount';
  static const editPrices       = 'edit_prices';
  static const viewAuditLog     = 'view_audit_log';
  static const manageStaff      = 'manage_staff';
  static const changeSecurity   = 'change_security';

  /// All 15 permissions in display order.
  static const all = <String>[
    viewDashboard,
    viewReports,
    viewProducts,
    editProducts,
    deleteProducts,
    viewCustomers,
    editCustomers,
    deleteCustomers,
    createSale,
    voidSale,
    applyDiscount,
    editPrices,
    viewAuditLog,
    manageStaff,
    changeSecurity,
  ];

  /// Human-readable labels for the Settings UI.
  static String label(String key) {
    switch (key) {
      case viewDashboard:   return 'Dashboard Dekhein';
      case viewReports:     return 'Reports Dekhein';
      case viewProducts:    return 'Products Dekhein';
      case editProducts:    return 'Products Edit Karein';
      case deleteProducts:  return 'Products Delete Karein';
      case viewCustomers:   return 'Customers/Suppliers Dekhein';
      case editCustomers:   return 'Customers/Suppliers Edit Karein';
      case deleteCustomers: return 'Customers/Suppliers Delete Karein';
      case createSale:      return 'Sale Entry Karein';
      case voidSale:        return 'Sale Void/Cancel Karein';
      case applyDiscount:   return 'Discount Apply Karein';
      case editPrices:      return 'Prices Change Karein';
      case viewAuditLog:    return 'Audit Log Dekhein';
      case manageStaff:     return 'Staff / Roles Manage Karein';
      case changeSecurity:  return 'Security Settings Badlein';
      default:              return key;
    }
  }
}

/// Default permission sets for the three built-in roles.
abstract class DefaultRolePermissions {
  static const owner = Permissions.all;

  static const manager = <String>[
    Permissions.viewDashboard,
    Permissions.viewReports,
    Permissions.viewProducts,
    Permissions.editProducts,
    Permissions.viewCustomers,
    Permissions.editCustomers,
    Permissions.createSale,
    Permissions.voidSale,
    Permissions.applyDiscount,
    Permissions.editPrices,
    Permissions.viewAuditLog,
    // Excluded: deleteProducts, deleteCustomers, manageStaff, changeSecurity
  ];

  static const cashier = <String>[
    Permissions.viewDashboard,
    Permissions.viewProducts,
    Permissions.viewCustomers,
    Permissions.createSale,
    // Minimal: no edit/delete/reports/audit/staff/security
  ];
}

/// Service for role-based access control — reads roles from DB, checks
/// permissions, and provides seed data for fresh installs.
class RbacService {
  RbacService._internal();
  static final RbacService instance = RbacService._internal();

  /// Loads all roles for the given company.
  Future<List<Map<String, dynamic>>> getRoles(int companyId) async {
    final db = await DBHelper.instance.database;
    return db.query('roles',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'id ASC');
  }

  /// Gets a single role by its ID.
  Future<Map<String, dynamic>?> getRoleById(int roleId) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query('roles', where: 'id = ?', whereArgs: [roleId]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Parses the JSON permissions column into a Set<String>.
  Set<String> parsePermissions(Map<String, dynamic> role) {
    final raw = role['permissions'] as String? ?? '[]';
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  /// Gets the number of custom (non-builtin) roles for a company.
  Future<int> getCustomRoleCount(int companyId) async {
    final db = await DBHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM roles WHERE company_id = ? AND is_builtin = 0',
      [companyId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Creates a new custom role. Returns its ID. Enforces the 1-custom-role
  /// limit per company (as per approved design).
  Future<int> createCustomRole({
    required int companyId,
    required String name,
    required List<String> permissions,
  }) async {
    final existing = await getCustomRoleCount(companyId);
    if (existing >= 1) {
      throw StateError(
        'Sirf 1 custom role bana sakte hain per company. '
        'Pehle purani custom role delete karein.',
      );
    }
    final db = await DBHelper.instance.database;
    return db.insert('roles', {
      'company_id': companyId,
      'name': name,
      'is_builtin': 0,
      'permissions': jsonEncode(permissions),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Updates a role's permissions (works for both builtin and custom).
  Future<void> updateRolePermissions(int roleId, List<String> permissions) async {
    final db = await DBHelper.instance.database;
    await db.update(
      'roles',
      {'permissions': jsonEncode(permissions)},
      where: 'id = ?',
      whereArgs: [roleId],
    );
  }

  /// Renames a custom role (builtin roles can't be renamed).
  Future<void> renameRole(int roleId, String newName) async {
    final db = await DBHelper.instance.database;
    final role = await getRoleById(roleId);
    if (role != null && (role['is_builtin'] as int) == 1) {
      throw StateError('Built-in roles rename nahi ho sakte.');
    }
    await db.update(
      'roles',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [roleId],
    );
  }

  /// Deletes a custom role. Built-in roles cannot be deleted.
  Future<void> deleteCustomRole(int roleId) async {
    final db = await DBHelper.instance.database;
    final role = await getRoleById(roleId);
    if (role != null && (role['is_builtin'] as int) == 1) {
      throw StateError('Built-in roles delete nahi ho sakte.');
    }
    await db.delete('roles', where: 'id = ?', whereArgs: [roleId]);
  }

  /// Looks up the role_id to use for the "owner" login (which bypasses
  /// the staff_users table). Returns the Owner role row for the given company.
  Future<Map<String, dynamic>?> getOwnerRole(int companyId) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query(
      'roles',
      where: 'company_id = ? AND name = ? AND is_builtin = 1',
      whereArgs: [companyId, 'Owner'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
