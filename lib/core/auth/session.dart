import 'rbac_service.dart';

/// In-memory record of who is currently using the app on this device.
/// Not persisted — every fresh PIN unlock re-establishes it.
///
/// RBAC-backed session: every login resolves to a role (Owner / Manager /
/// Accountant / Cashier / Custom) and a Set of permission keys. UI uses `Session.can(...)`
/// to gate features; `isOwner` is preserved for legacy call sites and
/// always true when roleName == 'Owner'.
class Session {
  Session._();

  // ---- Identity (set on PIN success) ----
  static int? _staffId; // null = owner (the PIN itself)
  static String? _staffName; // null for owner
  static int? _activeCompanyId; // for staff, locked to their company
  static String _userIdentifier = 'Owner'; // shown in audit log entries

  // ---- RBAC ----
  static int? _roleId;
  static String _roleName = 'Owner';
  static Set<String> _permissions = Set.from(AppPermissions.allPermissions);

  // ---- Accessors ----
  static String get role => _roleName.toLowerCase();
  static String? get staffName => _staffName;
  static bool get isOwner => _roleName.toLowerCase() == 'owner';
  static int? get staffId => _staffId;
  static int? get activeCompanyId => _activeCompanyId;
  static String get userIdentifier => _userIdentifier;
  static int? get roleId => _roleId;
  static String get roleName => _roleName;

  // ---- Setup ----

  /// Sets owner session with all permissions.
  static void setOwner({int? companyId, Set<String>? permissions}) {
    _staffId = null;
    _staffName = null;
    _activeCompanyId = companyId;
    _userIdentifier = 'Owner';
    _roleName = 'Owner';
    _permissions = permissions ?? Set.from(AppPermissions.allPermissions);
  }

  /// Sets legacy cashier session.
  static void setCashier(String name, {int? companyId}) {
    _staffId = null;
    _staffName = name;
    _activeCompanyId = companyId;
    _userIdentifier = 'Staff: $name';
    _roleName = 'Cashier';
    _permissions = DefaultRoles.getPermissionsForRole('Cashier');
  }

  /// Sets staff session with explicit role and permissions.
  static void setStaff({
    required int staffId,
    required String staffName,
    required int companyId,
    int? roleId,
    required String roleName,
    required Set<String> permissions,
  }) {
    _staffId = staffId;
    _staffName = staffName;
    _activeCompanyId = companyId;
    _userIdentifier = '$roleName ($staffName)';
    _roleId = roleId;
    _roleName = roleName;
    _permissions = permissions;
  }

  /// Permission check — single chokepoint for all RBAC decisions.
  /// Owner always gets `true`.
  static bool can(String permission) {
    if (isOwner) return true;
    return _permissions.contains(permission);
  }

  /// Convenience: returns true if any of the listed permissions is granted.
  static bool canAny(List<String> permissions) {
    if (isOwner) return true;
    return permissions.any((p) => _permissions.contains(p));
  }

  /// Convenience: returns true if ALL listed permissions are granted.
  static bool canAll(List<String> permissions) {
    if (isOwner) return true;
    return permissions.every((p) => _permissions.contains(p));
  }

  static void reloadPermissions(Set<String> permissions) {
    _permissions = permissions;
  }

  /// Wipes session state (PIN screen, app shutdown, etc.).
  static void clear() {
    _staffId = null;
    _staffName = null;
    _activeCompanyId = null;
    _userIdentifier = 'Owner';
    _roleId = null;
    _roleName = 'Owner';
    _permissions = Set.from(AppPermissions.allPermissions);
  }
}
