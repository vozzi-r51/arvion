import 'package:sentry_flutter/sentry_flutter.dart';

/// Telemetry & Crash-Free Session Monitor.
/// Tracks session health and error rates via Sentry telemetry to maintain > 99.5% crash-free target.
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  int _sessionCount = 0;
  int _errorCount = 0;

  int get sessionCount => _sessionCount;
  int get errorCount => _errorCount;

  /// Calculates Crash-Free Sessions percentage.
  double get crashFreeRate {
    if (_sessionCount == 0) return 100.0;
    final rate = ((_sessionCount - _errorCount) / _sessionCount) * 100.0;
    return rate.clamp(0.0, 100.0);
  }

  /// Records a new session startup.
  void recordSessionStart() {
    _sessionCount++;
  }

  /// Reports a non-fatal error / crash to Sentry and updates local crash-free telemetry.
  Future<void> logException(
    dynamic exception, {
    dynamic stackTrace,
    String? context,
  }) async {
    _errorCount++;
    try {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        hint: Hint.withMap({'context': context ?? 'General Exception'}),
      );
    } catch (_) {}
  }
}
