import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/database/bizmanager_db_migration.dart';
import 'core/services/error_reporter.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/terminology_provider.dart';
import 'core/providers/branding_provider.dart';
import 'core/providers/localization_provider.dart';
import 'core/backup/auto_sync_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Observability FIRST: any failure below this line (e.g. during DB
  // open) must still be captured rather than vanish. The reporter's own
  // init is fire-and-forget and never throws.
  ErrorReporter.instance.init();

  // One-shot DB file migration: if the user is upgrading from the
  // previous package (`com.arvion.dukanedge`) the encrypted DB lives
  // in a different Android data dir. We scan well-known legacy paths
  // and copy the file (plus its `-journal` / `-wal` / `-shm` sidecars)
  // into the new package's databases dir as `bizmanager.db`. This
  // MUST run before `setupServiceLocator()` so DBHelper opens the
  // already-migrated file. Idempotent and best-effort: any failure
  // is reported and swallowed so we never block startup.
  await BizManagerDbMigration.ensureMigrated();

  // Wire up the service locator (DB, event bus, repositories, listeners)
  // BEFORE anything else so the rest of the app can grab dependencies
  // via `sl<...>()` without order-of-init bugs.
  try {
    await setupServiceLocator();
  } catch (e, s) {
    // DB open or migration failed. The DB no longer silently re-opens
    // unencrypted, so this catch is the user-facing safety net. Show a
    // minimal red screen with the error and the persisted log path.
    ErrorReporter.instance.report(
      e,
      module: 'DB',
      action: 'open',
      stack: s.toString(),
      fatal: true,
    );
    runApp(_StartupErrorApp(error: e.toString()));
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final bool crashReportingEnabled =
      prefs.getBool('crash_reporting_enabled') ?? true;

  // Phase 58: initialize workmanager for cloud auto-sync background
  // tasks. `initialize` must be called before `runApp` so the platform
  // side registers our `autoSyncDispatcher` callback. We catch failures
  // so a misbehaving workmanager (e.g. on a fresh emulator) doesn't
  // block the rest of the app from starting.
  try {
    await Workmanager().initialize(
      autoSyncDispatcher,
      isInDebugMode: false,
    );
    await AutoSyncScheduler.instance.ensureRegistered();
  } catch (_) {
    // Auto-sync is best-effort. If the OS scheduler is unavailable the
    // app still works; users just lose the background trigger.
  }

  // Disable runtime fetching of fonts to ensure 100% offline operation.
  GoogleFonts.config.allowRuntimeFetching = false;

  if (crashReportingEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://example@sentry.io/example'; // TODO: Replace with real DSN
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
        // Phase 58: LocalizationProvider also drives MaterialApp.locale.
        // It is created here and init() is awaited before runApp so the
        // first frame already uses the persisted language.
        ChangeNotifierProvider(
          create: (_) => LocalizationProvider()..init(),
        ),
      ],
      child: const BizManagerApp(),
    ),
  );
}

/// Minimal "the app could not start" surface. Stays on screen until
/// the user dismisses; the persisted error log captures the stack for
/// later diagnosis.
class _StartupErrorApp extends StatelessWidget {
  final String error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Database could not be opened',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The encrypted database file failed to open. This usually '
                  'means the encryption key on this device is different '
                  'from the one used to create the data, or the file is '
                  'corrupt. Please reinstall the app and restore from a '
                  'backup.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
