import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/sync/hlc.dart';
import 'package:bizmanager/core/utils/uuid_v7.dart';

void main() {
  group('Hybrid Logical Clock (HLC) & UUIDv7 Unit Tests', () {
    setUp(() {
      HLC.resetState();
    });

    test('Monotonic clock advancement during physical time progression', () {
      final hlc1 = HLC.now('NODE-1');
      final hlc2 = HLC.now('NODE-1');

      expect(hlc2.compareTo(hlc1), greaterThanOrEqualTo(0));
      expect(hlc1.nodeId, 'NODE-1');
      expect(hlc2.nodeId, 'NODE-1');
    });

    test('Monotonic clock advancement during simulated backwards physical clock jump', () {
      final futureMillis = DateTime.now().millisecondsSinceEpoch + 100000;
      HLC.resetState(millis: futureMillis, counter: 5);

      final remoteHlc = HLC(futureMillis, 10, 'REMOTE-NODE');

      // Receive remote HLC
      final recvHlc = HLC.recv(remoteHlc, 'LOCAL-NODE');

      expect(recvHlc.millis, futureMillis);
      expect(recvHlc.counter, 11); // Counter incremented to maintain causality
      expect(recvHlc.nodeId, 'LOCAL-NODE');
    });

    test('HLC string serialization and parsing preserves fields', () {
      final hlc = HLC.now('NODE-XYZ');
      final str = hlc.toString();

      final parsed = HLC.parse(str);
      expect(parsed.millis, hlc.millis);
      expect(parsed.counter, hlc.counter);
      expect(parsed.nodeId, 'NODE-XYZ');
    });

    test('UUIDv7 generates 36-char time-ordered unique strings', () {
      final id1 = UUIDv7.generate();
      final id2 = UUIDv7.generate();

      expect(id1.length, 36);
      expect(id2.length, 36);
      expect(id1, isNot(equals(id2)));
    });
  });
}
