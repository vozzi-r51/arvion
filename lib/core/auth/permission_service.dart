class PermissionDeniedException implements Exception {
  final String permissionKey;
  PermissionDeniedException(this.permissionKey);

  @override
  String toString() =>
      'PermissionDeniedException: Missing required permission [$permissionKey]';
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Set<String> _activePermissions = {};

  void setActivePermissions(Set<String> permissions) {
    _activePermissions = Set.unmodifiable(permissions);
  }

  void clearPermissions() {
    _activePermissions = {};
  }

  bool hasPermission(String permissionKey) {
    // Owner or admin bypasses all permission checks
    if (_activePermissions.contains('*') ||
        _activePermissions.contains('all') ||
        _activePermissions.contains('owner') ||
        _activePermissions.contains('admin')) {
      return true;
    }
    return _activePermissions.contains(permissionKey);
  }

  void requirePermission(String permissionKey) {
    if (!hasPermission(permissionKey)) {
      throw PermissionDeniedException(permissionKey);
    }
  }
}
