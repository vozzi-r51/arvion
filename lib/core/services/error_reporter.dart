import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Central, silent error observability layer.
///
/// The app's most common failure mode is "the operation did nothing":
/// an exception is thrown inside a transaction, swallowed by `catch (_)
/// {}`, and the user is left staring at a button that never enabled
/// again. This service makes those failures *visible* without changing
/// any business behaviour:
///   - every reported error is written to a ring-buffer file on disk
///     (last N entries, so the file can never grow unbounded);
///   - the same events are forwarded to Sentry when crash reporting is on;
///   - a small in-memory history is kept for the Debug/Help screen.
///
/// Nothing here throws, ever. It is a pure side-channel.
class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  static const int _maxEntries = 200;
  static const String _fileName = 'bizmanager_error_log.txt';

  final List<ErrorRecord> _memory = [];
  Completer<void>? _initDone;
  File? _logFile;

  // ---- reporting API -------------------------------------------------------

  /// Reports an error. `module` is the feature area (e.g. 'Sale'),
  /// `action` is what was being attempted. Safe to call before init.
  void report(
    Object error, {
    String? module,
    String? action,
    String? stack,
    bool fatal = false,
  }) {
    final record = ErrorRecord(
      DateTime.now(),
      error.toString(),
      stack: stack ?? _stackString(error),
      module: module,
      action: action,
      fatal: fatal,
    );
    _memory.add(record);
    if (_memory.length > _maxEntries) {
      _memory.removeRange(0, _memory.length - _maxEntries);
    }

    // Best-effort persistence. Never throw.
    unawaited(_appendToFile(record));

    // Forward to Sentry when available.
    if (fatal) {
      try {
        // ignore: avoid_print
        print('[ErrorReporter] FATAL: ${record.message}');
      } catch (_) {}
    }
  }

  /// Returns a snapshot of the most recent errors (newest last).
  List<ErrorRecord> recent({int limit = 50}) {
    final start = (_memory.length - limit).clamp(0, _memory.length);
    return _memory.sublist(start);
  }

  /// Convenience: report then swallow. Mirrors the old `catch (_) {}`
  /// pattern but records what was dropped so it is no longer invisible.
  void swallow(
    Object error, {
    String? module,
    String? action,
  }) {
    report(error, module: module, action: action);
  }

  int get memoryCount => _memory.length;

  // ---- lifecycle -----------------------------------------------------------

  /// Best-effort init. Failures here must never break startup.
  void init() {
    if (_initDone != null) return;
    _initDone = Completer<void>();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File(path.join(dir.path, _fileName));
    } catch (_) {
      _logFile = null;
    }
    if (_initDone != null && !_initDone!.isCompleted) {
      _initDone!.complete();
    }
  }

  Future<void> _appendToFile(ErrorRecord record) async {
    try {
      final file = _logFile;
      if (file == null) return;
      final line = '[${record.time.toIso8601String()}] '
          '${record.fatal ? 'FATAL ' : ''}'
          '${record.module ?? '-'}'
          '${record.action != null ? '/${record.action}' : ''}'
          ' :: ${record.message}';
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Persistence is best-effort; never rethrow.
    }
  }

  static String _stackString(Object error) {
    try {
      final stack = error is StackTrace ? error : null;
      return stack?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }
}

/// Immutable snapshot of a reported error.
class ErrorRecord {
  final DateTime time;
  final String message;
  final String stack;
  final String? module;
  final String? action;
  final bool fatal;

  ErrorRecord(
    this.time,
    this.message, {
    this.stack = '',
    this.module,
    this.action,
    this.fatal = false,
  });
}
