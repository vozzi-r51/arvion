import 'rbac_service.dart';
import '../database/db_helper.dart';

/// Exception thrown when a user attempts an operation without required RBAC permissions.
class PermissionDeniedException implements Exception {
  final String permissionKey;
  final String message;

  PermissionDeniedException(this.permissionKey,
      [this.message = 'Permission denied for this operation.']);

  @override
  String toString() => 'PermissionDeniedException ($permissionKey): $message';
}

/// Centralized interceptor guard that validates granular RBAC permissions on all write services.
class PermissionGuard {
  PermissionGuard._();

  /// Keys for granular enterprise permissions
  static const String inventoryTransferCreate = 'inventory.transfer.create';
  static const String inventoryTransferApprove = 'inventory.transfer.approve';
  static const String accountsJournalPost = 'accounts.journal.post';
  static const String salesDiscountOverride = 'sales.discount.override';
  static const String p2pGrnCreate = 'p2p.grn.create';
  static const String p2pInvoiceCreate = 'p2p.invoice.create';

  /// Check if the user/role has permission; throws [PermissionDeniedException] if absent.
  static Future<void> checkPermission({
    required int companyId,
    required String permissionKey,
    String? userRole,
    int? userId,
  }) async {
    final allowed = await hasPermission(
      companyId: companyId,
      permissionKey: permissionKey,
      userRole: userRole,
      userId: userId,
    );

    if (!allowed) {
      throw PermissionDeniedException(
        permissionKey,
        'Aap ke pas "$permissionKey" perform karne ki ijazat nahi hai.',
      );
    }
  }

  /// Check if the permission is granted.
  static Future<bool> hasPermission({
    required int companyId,
    required String permissionKey,
    String? userRole,
    int? userId,
  }) async {
    // Owner / Admin role always bypasses checks
    if (userRole?.toLowerCase() == 'owner' ||
        userRole?.toLowerCase() == 'admin') {
      return true;
    }

    final db = await DBHelper.instance.database;

    // Check custom_roles table
    if (userRole != null) {
      final roleRows = await db.query(
        'custom_roles',
        where: 'company_id = ? AND LOWER(name) = ?',
        whereArgs: [companyId, userRole.toLowerCase()],
      );

      if (roleRows.isNotEmpty) {
        final permsJson = roleRows.first['permissions'] as String?;
        if (permsJson != null && permsJson.contains(permissionKey)) {
          return true;
        }
      }
    }

    // Default: Check against RbacService
    return await RbacService.instance.hasPermission(
      companyId: companyId,
      roleName: userRole ?? 'cashier',
      permissionKey: permissionKey,
    );
  }
}
