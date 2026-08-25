import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/arvion_brand.dart';
import '../company/company_selection_screen.dart';
import '../shell/main_shell.dart';
import '../../core/auth/session.dart';
import '../../core/database/db_helper.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _checking = false;
  bool _biometricAvailable = false;
  
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  static const String _prefFailedAttempts = 'auth_failed_attempts';
  static const String _prefLockoutUntil = 'auth_lockout_until';

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    _checkLockout();
  }

  Future<void> _checkLockout() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(_prefFailedAttempts) ?? 0;
    final lockoutUntil = prefs.getInt(_prefLockoutUntil) ?? 0;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockoutUntil > now) {
      _startLockoutTimer(lockoutUntil - now);
    }
  }

  void _startLockoutTimer(int durationMs) {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSeconds = (durationMs / 1000).ceil();
      _checking = false;
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_lockoutSeconds > 0) {
          _lockoutSeconds--;
        } else {
          _lockoutTimer?.cancel();
          _error = null;
        }
      });
    });
  }

  Future<void> _recordFailure() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts++;
    await prefs.setInt(_prefFailedAttempts, _failedAttempts);

    if (_failedAttempts >= 5) {
      // 30 second lockout after 5 fails, then maybe exponential or fixed?
      // Let's do 30s for every fail after 5.
      final duration = const Duration(seconds: 30);
      final lockoutUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
      await prefs.setInt(_prefLockoutUntil, lockoutUntil);
      _startLockoutTimer(duration.inMilliseconds);
    }
  }

  Future<void> _resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefFailedAttempts);
    await prefs.remove(_prefLockoutUntil);
    _failedAttempts = 0;
  }

  Future<void> _initBiometrics() async {
    final deviceSupports =
        await AuthService.instance.deviceSupportsBiometrics();
    final enabled = await AuthService.instance.isBiometricEnabled();
    if (!mounted) return;
    setState(() => _biometricAvailable = deviceSupports && enabled);
    if (_biometricAvailable && _lockoutSeconds <= 0) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_lockoutSeconds > 0) return;
    final success = await AuthService.instance.authenticateWithBiometrics();
    if (!mounted) return;
    if (success) {
      await _resetAttempts();
      Session.setOwner();
      _goToApp();
    }
  }

  Future<void> _verifyPin() async {
    if (_checking || _lockoutSeconds > 0) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final ownerValid =
          await AuthService.instance.verifyPin(_pinController.text);
      if (!mounted) return;
      if (ownerValid) {
        await _resetAttempts();
        Session.setOwner();
        _goToApp();
        return;
      }
      final staff =
          await AuthService.instance.verifyStaffPin(_pinController.text);
      if (!mounted) return;
      if (staff != null) {
        await _resetAttempts();
        Session.setCashier(staff['name'] as String);
        await DBHelper.instance.setActiveCompany(staff['company_id'] as int);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()));
        return;
      }
      
      await _recordFailure();
      setState(() {
        _checking = false;
        if (_lockoutSeconds > 0) {
          _error = 'Bohat zyada koshishain. Intezar karein.';
        } else {
          _error = 'Galat PIN, dobara koshish karein';
        }
        _pinController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Login service unavailable. Dobara koshish karein.';
      });
    }
  }

  void _goToApp() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompanySelectionScreen()));
  }

  Future<void> _forgotPin() async {
    if (_lockoutSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Intezar karein: $_lockoutSeconds seconds'))
      );
      return;
    }
    final info = await AuthService.instance.getSecurityInfo();
    if (!mounted) return;
    if (info == null || info['security_question'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Recovery data nahi mila. App reinstall karni paray gi.')));
      return;
    }
    final answerCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset App PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sawal: ${info['security_question']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                  controller: answerCtrl,
                  decoration: const InputDecoration(labelText: 'Aapka Jawab')),
              const Divider(height: 32),
              TextField(
                  controller: newPinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Naya PIN')),
              TextField(
                  controller: confirmPinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Naya PIN Confirm')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok =
                  await AuthService.instance.verifyRecovery(answerCtrl.text);
              if (!ok || !ctx.mounted) return;
              if (newPinCtrl.text != confirmPinCtrl.text ||
                  newPinCtrl.text.length < 4) return;
              await AuthService.instance.setPin(newPinCtrl.text,
                  question: info['security_question'], answer: answerCtrl.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN reset ho gaya.')));
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = _lockoutSeconds > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text('ARVION',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                          color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text('Business, clearly managed.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: const Color(0xFF475569))),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Sign in',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            isLocked 
                              ? 'Security lockout active. Please wait.'
                              : 'Enter your secure PIN to continue',
                            style: TextStyle(
                              color: isLocked ? Colors.red : const Color(0xFF64748B)
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _pinController,
                            enabled: !isLocked,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24, 
                              letterSpacing: 8,
                              color: isLocked ? Colors.grey : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: isLocked ? 'LOCKED' : 'PIN', 
                              counterText: '',
                              prefixIcon: isLocked ? const Icon(Icons.timer, color: Colors.red) : null,
                            ),
                            onSubmitted: (_) => _verifyPin(),
                          ),
                          if (isLocked)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Intezar karein: $_lockoutSeconds seconds',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            )
                          else if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: (_checking || isLocked) ? null : _verifyPin,
                            child: _checking
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(isLocked ? 'Locked' : 'Sign In'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                              onPressed: isLocked ? null : _forgotPin,
                              child: const Text('Forgot Password')),
                          if (_biometricAvailable && !isLocked)
                            TextButton.icon(
                                onPressed: _tryBiometric,
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('Biometric login')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Developed by ARVION Technologies',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
