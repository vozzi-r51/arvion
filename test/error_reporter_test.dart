import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/services/error_reporter.dart';

void main() {
  test('ErrorReporter records errors and never throws', () {
    final reporter = ErrorReporter.instance;
    reporter.report(
      FormatException('bad json'),
      module: 'Sale',
      action: 'create',
      stack: 'line 1\nline 2',
    );

    final recent = reporter.recent(limit: 10);
    expect(recent, isNotEmpty);
    final last = recent.last;
    expect(last.message, contains('bad json'));
    expect(last.module, 'Sale');
    expect(last.action, 'create');
    expect(last.stack, contains('line 1'));
    expect(last.fatal, isFalse);
  });

  test('swallow() is a silent report', () {
    final before = ErrorReporter.instance.memoryCount;
    ErrorReporter.instance.swallow(
      ArgumentError('boom'),
      module: 'Company',
      action: 'decode_enabled_modules',
    );
    expect(ErrorReporter.instance.memoryCount, before + 1);
  });

  test('ring buffer caps at maxEntries', () {
    final reporter = ErrorReporter.instance;
    for (var i = 0; i < 250; i++) {
      reporter.report('overflow-$i');
    }
    expect(reporter.memoryCount, lessThanOrEqualTo(200));
    // The newest entries must be retained, the oldest dropped.
    final recent = reporter.recent(limit: 5);
    expect(recent.last.message, contains('overflow-249'));
  });
}
