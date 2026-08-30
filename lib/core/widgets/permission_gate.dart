import 'package:flutter/material.dart';
import '../auth/permission_service.dart';

class PermissionGate extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final bool allowed = PermissionService().hasPermission(permission);
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
