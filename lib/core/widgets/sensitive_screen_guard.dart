import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../features/auth/pin_login_screen.dart';

/// A wrapper widget that enforces screen-level auto-lock / timeout granularity
/// for sensitive screens (e.g. Reports, Settings, Financial Ledgers).
class SensitiveScreenGuard extends StatefulWidget {
  final Widget child;
  final String screenName;

  const SensitiveScreenGuard({
    super.key,
    required this.child,
    required this.screenName,
  });

  @override
  State<SensitiveScreenGuard> createState() => _SensitiveScreenGuardState();
}

class _SensitiveScreenGuardState extends State<SensitiveScreenGuard> {
  Timer? _inactivityTimer;
  int _timeoutSeconds = 30; // default 30s for sensitive screens

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStartTimer();
  }

  Future<void> _loadSettingsAndStartTimer() async {
    final prefs = await SharedPreferences.getInstance();
    _timeoutSeconds = prefs.getInt('sensitive_screen_lock_seconds') ?? 30;
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    if (_timeoutSeconds <= 0) return; // 0 = disabled

    _inactivityTimer = Timer(Duration(seconds: _timeoutSeconds), _onTimeout);
  }

  void _onTimeout() {
    if (!mounted) return;

    // Lock app and prompt PIN
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );

    ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text(
            '${widget.screenName} par $_timeoutSeconds sec ki inactivity ki wajah se app lock ho gayi.'),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeoutSeconds <= 0) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
