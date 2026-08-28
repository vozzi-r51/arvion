import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

/// All discrete permission constants across BizManager modules.
abstract class AppPermissions {
  static const viewDashboard          = 'view_dashboard';
  static const viewReports            = 'view_reports';
  static const viewSales              = 'view_sales';
  static const createSales            = 'create_sales';
  static const editSales              = 'edit_sales';
  static const deleteSales            = 'delete_sales';

  static const viewPurchases          = 'view_purchases';
  static const createPurchases        = 'create_purchases';
  static const editPurchases          = 'edit_purchases';
  static const deletePurchases        = 'delete_purchases';
  static const approvePo              = 'approve_po';

  static const viewCustomers          = 'view_customers';
  static const editCustomers          = 'edit_customers';
  static const deleteCustomers        = 'delete_customers';

  static const viewSuppliers          = 'view_suppliers';
  static const editSuppliers          = 'edit_suppliers';
  static const deleteSuppliers        = 'delete_suppliers';

  static const viewInventory          = 'view_inventory';
  static const editInventory          = 'edit_inventory';
  static const adjustStock            = 'adjust_stock';
  static const editPrices             = 'edit_prices';

  static const viewExpenses           = 'view_expenses';
  static const createExpenses         = 'create_expenses';
  static const editExpenses           = 'edit_expenses';
  static const deleteExpenses         = 'delete_expenses';

  static const viewAccounting         = 'view_accounting';
  static const deleteRecords          = 'delete_records';
  static const manageUsers            = 'manage_users';
  static const manageRoles            = 'manage_roles';
  static const manageCompanySettings  = 'manage_company_settings';

  static const viewAuditLog           = 'view_audit_log';
  static const exportData             = 'export_data';
  static const importData             = 'import_data';

  /// List of all system permissions.
  static const all = <String>[
    viewDashboard, viewReports,
    viewSales, createSales, editSales, deleteSales,
    viewPurchases, createPurchases, editPurchases, deletePurchases, approvePo,
    viewCustomers, editCustomers, deleteCustomers,
    viewSuppliers, editSuppliers, deleteSuppliers,
    viewInventory, editInventory, adjustStock, editPrices,
    viewExpenses, createExpenses, editExpenses, deleteExpenses,
    viewAccounting, deleteRecords, manageUsers, manageRoles, manageCompanySettings,
    viewAuditLog, exportData, importData,
  ];
}

/// Backward compatibility alias for legacy code references.
typedef Permissions = AppPermissions;

/// Central Granular Role-Based Access Control (RBAC) Service.
/// Evaluates permissions and enforces service-level authorization boundaries.
class RbacService {
  RbacService._internal();
  static final RbacService instance = RbacService._internal();

  final Map<String, bool> _permissionCache = {};

  /// Checks whether a specific role in a company has a permission.
  /// Owner role always evaluates to true (full administrative access).
  Future<bool> hasPermission({
    required int companyId,
    required String roleName,
    required String permissionKey,
  }) async {
    if (roleName.toLowerCase() == 'owner') return true;

    final cacheKey = '$companyId:$roleName:$permissionKey';
    if (_permissionCache.containsKey(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    final db = await DBHelper.instance.database;

    // 1. Query role_permissions table
    final rows = await db.query(
      'role_permissions',
      columns: ['allowed'],
      where: 'company_id = ? AND role_name = ? AND permission_key = ?',
      whereArgs: [companyId, roleName, permissionKey],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final isAllowed = (rows.first['allowed'] as int) == 1;
      _permissionCache[cacheKey] = isAllowed;
      return isAllowed;
    }

    // 2. Fallback to roles table JSON permissions column
    final roleRows = await db.query(
      'roles',
      columns: ['permissions'],
      where: 'company_id = ? AND name = ?',
      whereArgs: [companyId, roleName],
      limit: 1,
    );

    if (roleRows.isNotEmpty) {
      final rawJson = roleRows.first['permissions'] as String? ?? '[]';
      try {
        final List<dynamic> list = jsonDecode(rawJson);
        final isAllowed = list.contains(permissionKey);
        _permissionCache[cacheKey] = isAllowed;
        return isAllowed;
      } catch (_) {}
    }

    // Cashier default fallbacks
    if (roleName.toLowerCase() == 'cashier') {
      final isCashierAllowed = permissionKey == AppPermissions.viewDashboard ||
          permissionKey == AppPermissions.viewSales ||
          permissionKey == AppPermissions.createSales ||
          permissionKey == AppPermissions.viewCustomers;
      _permissionCache[cacheKey] = isCashierAllowed;
      return isCashierAllowed;
    }

    _permissionCache[cacheKey] = false;
    return false;
  }

  /// Service-level authorization enforcement at method boundaries.
  /// Throws StateError if permission is denied.
  Future<void> requirePermission({
    required int companyId,
    required String roleName,
    required String permissionKey,
  }) async {
    final allowed = await hasPermission(
      companyId: companyId,
      roleName: roleName,
      permissionKey: permissionKey,
    );

    if (!allowed) {
      throw StateError(
        'Access Denied: Role "$roleName" does not have required permission "$permissionKey"',
      );
    }
  }

  /// Grants or revokes a granular permission for a role in a company.
  Future<void> setPermission({
    required int companyId,
    required String roleName,
    required String permissionKey,
    required bool allowed,
  }) async {
    final db = await DBHelper.instance.database;

    await db.insert(
      'role_permissions',
      {
        'company_id': companyId,
        'role_name': roleName,
        'permission_key': permissionKey,
        'allowed': allowed ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    clearCache();
  }

  /// Clears in-memory permission cache upon role/company changes or logout.
  void clearCache() {
    _permissionCache.clear();
  }

  // --- Legacy Role Helper Methods (Preserved for compatibility) ---

  Future<List<Map<String, dynamic>>> getRoles(int companyId) async {
    final db = await DBHelper.instance.database;
    return db.query('roles', where: 'company_id = ?', whereArgs: [companyId], orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>?> getRoleById(int roleId) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query('roles', where: 'id = ?', whereArgs: [roleId]);
    return rows.isEmpty ? null : rows.first;
  }

  Set<String> parsePermissions(Map<String, dynamic> role) {
    final raw = role['permissions'] as String? ?? '[]';
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  Future<int> createCustomRole({
    required int companyId,
    required String name,
    required List<String> permissions,
  }) async {
    final db = await DBHelper.instance.database;
    final roleId = await db.insert('roles', {
      'company_id': companyId,
      'name': name,
      'is_builtin': 0,
      'permissions': jsonEncode(permissions),
      'created_at': DateTime.now().toIso8601String(),
    });

    for (final pKey in permissions) {
      await setPermission(companyId: companyId, roleName: name, permissionKey: pKey, allowed: true);
    }

    return roleId;
  }

  Future<void> updateRolePermissions(int roleId, List<String> permissions) async {
    final db = await DBHelper.instance.database;
    final role = await getRoleById(roleId);

    await db.update(
      'roles',
      {'permissions': jsonEncode(permissions)},
      where: 'id = ?',
      whereArgs: [roleId],
    );

    if (role != null) {
      final cId = role['company_id'] as int;
      final rName = role['name'] as String;
      for (final pKey in permissions) {
        await setPermission(companyId: cId, roleName: rName, permissionKey: pKey, allowed: true);
      }
    }
  }

  Future<void> deleteCustomRole(int roleId) async {
    final db = await DBHelper.instance.database;
    final role = await getRoleById(roleId);
    if (role != null && (role['is_builtin'] as int) == 1) {
      throw StateError('Built-in roles delete nahi ho sakte.');
    }
    await db.delete('roles', where: 'id = ?', whereArgs: [roleId]);
    clearCache();
  }
}
