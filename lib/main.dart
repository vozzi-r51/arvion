import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/terminology_provider.dart';
import 'core/providers/branding_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wire up the service locator (DB, event bus, repositories, listeners)
  // BEFORE anything else so the rest of the app can grab dependencies
  // via `sl<...>()` without order-of-init bugs.
  await setupServiceLocator();

  final prefs = await SharedPreferences.getInstance();
  final bool crashReportingEnabled = prefs.getBool('crash_reporting_enabled') ?? true;

  // Disable runtime fetching of fonts to ensure 100% offline operation.
  GoogleFonts.config.allowRuntimeFetching = false;

  if (crashReportingEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = 'https://example@sentry.io/example'; // TODO: Replace with real DSN
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => _runApp(),
    );
  } else {
    _runApp();
  }
}

void _runApp() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TerminologyProvider()),
        ChangeNotifierProvider(create: (_) => BrandingProvider()),
      ],
      child: const DukanEdgeApp(),
    ),
  );
}
