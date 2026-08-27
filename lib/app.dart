import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'core/widgets/arvion_logo.dart';
import 'core/providers/branding_provider.dart';
import 'core/providers/localization_provider.dart';
import 'features/auth/pin_setup_screen.dart';
import 'features/auth/pin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Moved declarations here to ensure no directives follow
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class DukanEdgeApp extends StatefulWidget {
  const DukanEdgeApp({super.key});

  @override
  State<DukanEdgeApp> createState() => _DukanEdgeAppState();
}

class _DukanEdgeAppState extends State<DukanEdgeApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoLock();
    }
  }

  Future<void> _checkAutoLock() async {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    _pausedAt = null;

    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt('auto_lock_minutes') ?? 2;
    if (minutes == 0) return; // auto-lock disabled

    final elapsedMinutes = DateTime.now().difference(pausedAt).inMinutes;
    if (elapsedMinutes < minutes) return;

    final pinSet = await AuthService.instance.isPinSet();
    if (!pinSet) return;

    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'DukanEdge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeWithPrimary(themeProvider.primaryColor),
      darkTheme: AppTheme.darkThemeWithPrimary(themeProvider.primaryColor),
      themeMode: themeProvider.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
        Locale('ar'),
      ],
      home: const _SplashDecider(),
    );
  }
}

class _ARVIONSplashScreen extends StatefulWidget {
  const _ARVIONSplashScreen();

  @override
  State<_ARVIONSplashScreen> createState() => _ARVIONSplashScreenState();
}

class _ARVIONSplashScreenState extends State<_ARVIONSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _falconScale;
  late final Animation<double> _textReveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _falconScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _textReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.watch<BrandingProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // Background Grid effect
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(
                    painter: _GridPainter(),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // New Arvion Brand Icon
                    Opacity(
                      opacity: _textReveal.value,
                      child: Transform.scale(
                        scale: _falconScale.value,
                        child: branding.logoPath != null 
                          ? Image.file(File(branding.logoPath!), width: 120, height: 120)
                          : const ArvionLogo(size: 120),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // "ARVION" Text
                    Opacity(
                      opacity: _textReveal.value,
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * _textReveal.value),
                        child: Column(
                          children: [
                            Text(
                              branding.companyName.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              width: 60 * _textReveal.value,
                              color: branding.primaryColor,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'POWERED BY ARVION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white38,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    const step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Checks whether a PIN already exists and routes to the correct screen.
class _SplashDecider extends StatefulWidget {
  const _SplashDecider();

  @override
  State<_SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<_SplashDecider> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await context.read<BrandingProvider>().loadBranding();
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    final pinSet = await AuthService.instance.isPinSet();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            pinSet ? const PinLoginScreen() : const PinSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _ARVIONSplashScreen();
  }
}
