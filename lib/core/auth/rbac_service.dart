import 'dart:convert';

/// System permission keys for Enterprise-Trust Granular RBAC.
class AppPermissions {
  AppPermissions._();

  static const canViewReports = 'can_view_reports';
  static const canEditPrices = 'can_edit_prices';
  static const canDeleteRecords = 'can_delete_records';
  static const canApprovePurchaseOrders = 'can_approve_purchase_orders';
  static const canManageInventory = 'can_manage_inventory';
  static const canManageFinance = 'can_manage_finance';
  static const canManageHr = 'can_manage_hr';
  static const canManageCustomers = 'can_manage_customers';
  static const canManageSettings = 'can_manage_settings';

  static const List<String> allPermissions = [
    canViewReports,
    canEditPrices,
    canDeleteRecords,
    canApprovePurchaseOrders,
    canManageInventory,
    canManageFinance,
    canManageHr,
    canManageCustomers,
    canManageSettings,
  ];

  static const Map<String, String> labels = {
    canViewReports: 'Reports & Analytics Dekhein',
    canEditPrices: 'Prices & Discounts Change Karein',
    canDeleteRecords: 'Records Delete Karein',
    canApprovePurchaseOrders: 'Purchase Orders & Quotations Approve Karein',
    canManageInventory: 'Products & Stock Adjustments Manage Karein',
    canManageFinance: 'Expenses, Cash Book & Bank Accounts Manage Karein',
    canManageHr: 'Employees, Attendance & Salaries Manage Karein',
    canManageCustomers: 'Customers & Suppliers Manage Karein',
    canManageSettings: 'Company Settings & Staff Users Manage Karein',
  };

  static const Map<String, String> descriptions = {
    canViewReports: 'Profit/Loss, Tax, Sales aur Stock Reports ka full view',
    canEditPrices: 'Sale ya Product form mein unit price/discount modify karne ki permission',
    canDeleteRecords: 'Sales, Purchases, Customers ya Products permanent delete karne ki ijazat',
    canApprovePurchaseOrders: 'PO aur Quotation ko confirm aur convert karne ki ijazat',
    canManageInventory: 'Naye products add karna, stock adjust karna aur BOM/Production',
    canManageFinance: 'Expenses/Income entries, Cash Book aur Journal entries',
    canManageHr: 'Staff attendance, advance payment aur monthly salary process',
    canManageCustomers: 'Naye customers/suppliers banana aur ledgers view karna',
    canManageSettings: 'Company details, PIN, backup/restore aur staff permissions',
  };
}

/// Pre-defined standard enterprise roles.
class DefaultRoles {
  DefaultRoles._();

  static const owner = 'Owner';
  static const manager = 'Manager';
  static const accountant = 'Accountant';
  static const cashier = 'Cashier';

  static Set<String> getPermissionsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Set.from(AppPermissions.allPermissions);
      case 'manager':
        return {
          AppPermissions.canViewReports,
          AppPermissions.canEditPrices,
          AppPermissions.canApprovePurchaseOrders,
          AppPermissions.canManageInventory,
          AppPermissions.canManageFinance,
          AppPermissions.canManageHr,
          AppPermissions.canManageCustomers,
        };
      case 'accountant':
        return {
          AppPermissions.canViewReports,
          AppPermissions.canManageFinance,
          AppPermissions.canManageCustomers,
        };
      case 'cashier':
      default:
        return {
          AppPermissions.canManageCustomers,
        };
    }
  }
}

/// Model for custom created staff roles.
class CustomRole {
  final int? id;
  final int companyId;
  final String name;
  final String? description;
  final Set<String> permissions;

  CustomRole({
    this.id,
    required this.companyId,
    required this.name,
    this.description,
    required this.permissions,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'company_id': companyId,
      'name': name,
      'description': description,
      'permissions': jsonEncode(permissions.toList()),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory CustomRole.fromMap(Map<String, dynamic> map) {
    Set<String> perms = {};
    if (map['permissions'] != null) {
      try {
        final List list = jsonDecode(map['permissions'] as String);
        perms = list.map((e) => e.toString()).toSet();
      } catch (_) {}
    }
    return CustomRole(
      id: map['id'] as int?,
      companyId: map['company_id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      permissions: perms,
    );
  }
}
