import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_service.dart';
import 'google_drive_service.dart';

/// Phase 58 — Cloud Auto-Sync scheduler.
///
/// Why a separate class from [BackupService]:
///   - [BackupService] is the *mechanism* (zip + upload). It already has
///     `maybeRunAutoBackup()` that runs whenever the app happens to be
///     opened, gated by a 7-day interval.
///   - [AutoSyncScheduler] is the *trigger* that turns that on a real
///     background schedule using `workmanager`, so backups keep happening
///     even if the user never opens the app. It also adds:
///       * Wi-Fi-only constraint
///       * Frequency selection (6h / 12h / 24h)
///       * Last-synced timestamp tracking
///       * Foreground + background entry-point routing
///
/// The class is a thin layer on top of `workmanager`; the heavy lifting
/// (zip + upload) still happens in [BackupService] / [GoogleDriveService].
class AutoSyncScheduler {
  AutoSyncScheduler._();
  static final AutoSyncScheduler instance = AutoSyncScheduler._();

  /// Unique workmanager task name. Must be a top-level / static const.
  static const String taskName = 'bizmanager_auto_sync_task';

  /// Must match the name passed to [Workmanager.executeTask] in the
  /// top-level [autoSyncDispatcher] callback.
  static const String _uniqueWorkName = 'bizmanager_auto_sync';

  // ---------------------------------------------------------------------------
  // SharedPreferences keys (mirrored in UI for display).
  // ---------------------------------------------------------------------------
  static const String _prefEnabled = 'auto_sync_enabled';
  static const String _prefFrequencyHours = 'auto_sync_frequency_hours';
  static const String _prefWifiOnly = 'auto_sync_wifi_only';
  static const String _prefLastSyncedAt = 'auto_sync_last_synced_at';
  static const String _prefLastSyncStatus = 'auto_sync_last_sync_status';

  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------
  static const int _defaultFrequencyHours = 24;
  static const bool _defaultWifiOnly = true;

  // ---------------------------------------------------------------------------
  // Public API — read state.
  // ---------------------------------------------------------------------------
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false; // OFF by default
  }

  Future<int> getFrequencyHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefFrequencyHours) ?? _defaultFrequencyHours;
  }

  Future<bool> isWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefWifiOnly) ?? _defaultWifiOnly;
  }

  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_prefLastSyncedAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<String?> getLastSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLastSyncStatus);
  }

  // ---------------------------------------------------------------------------
  // Public API — write state and reconfigure the schedule.
  // ---------------------------------------------------------------------------

  /// Enable / disable the schedule. When disabling, also cancels the
  /// pending workmanager task so the OS doesn't wake the device for it.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, enabled);

    if (enabled) {
      await reschedule();
    } else {
      await Workmanager().cancelByUniqueName(_uniqueWorkName);
    }
  }

  Future<void> setFrequencyHours(int hours) async {
    assert(hours >= 1 && hours <= 168,
        'Frequency must be between 1 and 168 hours (1 week).');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefFrequencyHours, hours);
    if (await isEnabled()) {
      await reschedule();
    }
  }

  Future<void> setWifiOnly(bool wifiOnly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefWifiOnly, wifiOnly);
    if (await isEnabled()) {
      await reschedule();
    }
  }

  /// Re-register the periodic task using the current preferences.
  Future<void> reschedule() async {
    await Workmanager().cancelByUniqueName(_uniqueWorkName);
    final wifiOnly = await isWifiOnly();
    final hours = await getFrequencyHours();
    final initialDelay = Duration(minutes: 15); // never run immediately

    try {
      await Workmanager().registerPeriodicTask(
        _uniqueWorkName,
        taskName,
        // Frequency must be >= 15 min per workmanager API.
        frequency: Duration(hours: hours),
        initialDelay: initialDelay,
        constraints: wifiOnly
            ? Constraints(networkType: NetworkType.unmetered)
            : Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 10),
      );
    } catch (e, s) {
      // Workmanager can fail on emulators / dev hosts that don't have
      // the platform-side scheduler registered. Surface the error to the
      // logger but do not crash the app — auto-sync will just be inert
      // until next reschedule.
      if (kDebugMode) {
        debugPrint('AutoSyncScheduler.reschedule failed: $e\n$s');
      }
    }
  }

  /// Runs once on cold start: if the user had auto-sync enabled, ensure
  /// the workmanager task is registered. Workmanager doesn't persist
  /// tasks across app updates, so this is necessary.
  Future<void> ensureRegistered() async {
    if (!await isEnabled()) return;
    await reschedule();
  }

  /// Foreground entry-point: performs one sync attempt immediately and
  /// records the result. Used by the "Sync Now" button in Settings.
  /// Returns true on success.
  Future<bool> runOnce({bool force = false}) async {
    try {
      final wifiOnly = await isWifiOnly();
      if (!await _networkMeetsConstraint(wifiOnly)) {
        await recordSyncResult(
          ok: false,
          message: wifiOnly ? 'Wi-Fi not available' : 'No network',
        );
        return false;
      }
      if (!await GoogleDriveService.isAutoUploadEnabled() && !force) {
        await recordSyncResult(
          ok: false,
          message: 'Cloud upload disabled in settings',
        );
        return false;
      }
      if (!await GoogleDriveService.instance.isSignedIn()) {
        final acct = await GoogleDriveService.instance.signInSilently();
        if (acct == null) {
          await recordSyncResult(
            ok: false,
            message: 'Google account not signed in',
          );
          return false;
        }
      }
      final zipPath = await BackupService.createBackupZip();
      await GoogleDriveService.instance.uploadBackup(zipPath);
      await recordSyncResult(ok: true, message: null);
      return true;
    } catch (e) {
      await recordSyncResult(ok: false, message: '$e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — the actual work done by the OS-scheduled task.
  // ---------------------------------------------------------------------------

  /// Records the outcome of the most recent auto-sync attempt. Called
  /// from [autoSyncDispatcher] (background) and from the manual "Sync
  /// Now" button (foreground).
  static Future<void> recordSyncResult({
    required bool ok,
    required String? message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefLastSyncedAt, DateTime.now().toIso8601String());
    await prefs.setString(
      _prefLastSyncStatus,
      ok ? 'ok' : 'failed: ${message ?? 'unknown'}',
    );
  }

  /// Honors the user-configured Wi-Fi-only constraint at the Dart level.
  /// Workmanager's [Constraints] for [NetworkType.unmetered] is honoured
  /// by the OS scheduler, but on platforms where the platform-side
  /// check is unreliable (older Android, custom OEMs) we re-check here
  /// before doing the expensive zip + upload.
  static Future<bool> _networkMeetsConstraint(bool wifiOnly) async {
    final results = await Connectivity().checkConnectivity();
    final hasAny = results.any((r) => r != ConnectivityResult.none);
    if (!hasAny) return false;
    if (!wifiOnly) return true;
    return results.contains(ConnectivityResult.wifi);
  }
}

/// Top-level entry point that workmanager invokes from the OS scheduler.
///
/// **Must be a top-level function** (or static) so the platform-side
/// isolate can find it. The `task` argument is filled in by workmanager
/// at dispatch time.
@pragma('vm:entry-point')
void autoSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final wifiOnly = await AutoSyncScheduler.instance.isWifiOnly();
      if (!await AutoSyncScheduler._networkMeetsConstraint(wifiOnly)) {
        await AutoSyncScheduler.recordSyncResult(
          ok: false,
          message: wifiOnly
              ? 'Wi-Fi not available'
              : 'No network connection',
        );
        // Returning true (not false) tells workmanager the task ran;
        // returning false would force an immediate retry.
        return true;
      }

      if (!await GoogleDriveService.isAutoUploadEnabled()) {
        // User enabled auto-sync but disabled cloud upload — still
        // perform a local backup so the on-device copy is fresh.
        final zipPath = await BackupService.createBackupZip();
        // We intentionally do not record a successful "sync" here
        // because the cloud copy was not updated.
        await AutoSyncScheduler.recordSyncResult(
          ok: false,
          message: 'Cloud upload disabled (zip at $zipPath)',
        );
        return true;
      }

      if (!await GoogleDriveService.instance.isSignedIn()) {
        // Silent sign-in to refresh a possibly-expired token.
        final acct = await GoogleDriveService.instance.signInSilently();
        if (acct == null) {
          await AutoSyncScheduler.recordSyncResult(
            ok: false,
            message: 'Google account not signed in',
          );
          return true;
        }
      }

      final zipPath = await BackupService.createBackupZip();
      await GoogleDriveService.instance.uploadBackup(zipPath);
      await AutoSyncScheduler.recordSyncResult(ok: true, message: null);
      return true;
    } catch (e) {
      await AutoSyncScheduler.recordSyncResult(ok: false, message: '$e');
      return true;
    }
  });
}
