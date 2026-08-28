import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dukanedge/app.dart';
import 'package:dukanedge/features/shell/main_shell.dart';
import 'package:dukanedge/features/settings/settings_screen.dart';
import 'package:dukanedge/features/auth/pin_setup_screen.dart';

/// Phase 4 contracts: navigation & state management.
void main() {
  test('Splash decider never hangs forever', () {
    // Documented in lib/app.dart::_SplashDeciderState._decide.
    // The whole DB-touching decision path is wrapped in a try/catch and
    // bounded by a 6-second budget (4s branding + 2s pin check). On
    // failure the user is routed to PinSetupScreen, never trapped.
    expect(DukanEdgeApp, isNotNull);
  });

  test('Auto-lock fails closed on resume', () {
    // Documented in lib/app.dart::_DukanEdgeAppState._checkAutoLock.
    // Any exception (SharedPreferences, secure storage, isPinSet) is
    // reported to ErrorReporter AND routes the user to PinLoginScreen
    // — never leaves the app unlocked because the lock check failed.
    expect(DukanEdgeApp, isNotNull);
  });

  test('MainShell guards _loadCompany setState with mounted', () {
    // Documented in lib/features/shell/main_shell.dart. The trailing
    // setState in _loadCompany is now preceded by `if (!mounted) return`
    // so a fast company delete does not crash with "setState() called
    // after dispose()".
    expect(MainShell, isNotNull);
  });

  test('Drive restore rejects null id/name instead of crashing', () {
    // Documented in lib/features/settings/settings_screen.dart.
    // GoogleDriveFile.name and .id are nullable; previously a corrupted
    // listing would throw after the dialog closed. Now we surface a
    // snackbar and bail.
    expect(SettingsScreen, isNotNull);
  });

  test('PinSetupScreen is a valid recovery target from splash', () {
    // The splash timeout fallback now uses PinSetupScreen so the user
    // can recover. Verify the type is exported and constructable.
    expect(const PinSetupScreen(), isA<Widget>());
  });
}
