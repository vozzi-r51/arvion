import 'dart:math';

/// Hybrid Logical Clock (HLC) maintaining physical wall-clock time in millis,
/// counter, and node ID for causal event order across physical clock drifts.
class HLC implements Comparable<HLC> {
  final int millis;
  final int counter;
  final String nodeId;

  static int _lastMillis = 0;
  static int _lastCounter = 0;

  const HLC(this.millis, this.counter, this.nodeId);

  /// Get current HLC timestamp
  static HLC now(String nodeId) {
    final phys = DateTime.now().millisecondsSinceEpoch;
    if (phys > _lastMillis) {
      _lastMillis = phys;
      _lastCounter = 0;
    } else {
      _lastCounter++;
    }
    return HLC(_lastMillis, _lastCounter, nodeId);
  }

  /// Advance clock for sending a message
  static HLC send(String nodeId) => now(nodeId);

  /// Advance clock on receiving a remote message with [remoteHlc]
  static HLC recv(HLC remoteHlc, String nodeId) {
    final phys = DateTime.now().millisecondsSinceEpoch;
    final maxPhys = max(phys, max(_lastMillis, remoteHlc.millis));

    if (maxPhys == _lastMillis && maxPhys == remoteHlc.millis) {
      _lastCounter = max(_lastCounter, remoteHlc.counter) + 1;
    } else if (maxPhys == _lastMillis) {
      _lastCounter++;
    } else if (maxPhys == remoteHlc.millis) {
      _lastCounter = remoteHlc.counter + 1;
    } else {
      _lastCounter = 0;
    }

    _lastMillis = maxPhys;
    return HLC(_lastMillis, _lastCounter, nodeId);
  }

  /// Reset internal state (useful for tests simulating physical clock drift)
  static void resetState({int millis = 0, int counter = 0}) {
    _lastMillis = millis;
    _lastCounter = counter;
  }

  /// Format as string: "<millis>-<counter>-<nodeId>"
  @override
  String toString() {
    final cStr = counter.toString().padLeft(4, '0');
    return '$millis-$cStr-$nodeId';
  }

  /// Parse string back to HLC: "<millis>-<counter>-<nodeId>"
  static HLC parse(String formatted) {
    final firstDash = formatted.indexOf('-');
    if (firstDash == -1) return HLC(DateTime.now().millisecondsSinceEpoch, 0, 'node');

    final secondDash = formatted.indexOf('-', firstDash + 1);
    if (secondDash == -1) return HLC(DateTime.now().millisecondsSinceEpoch, 0, 'node');

    final mStr = formatted.substring(0, firstDash);
    final cStr = formatted.substring(firstDash + 1, secondDash);
    final node = formatted.substring(secondDash + 1);

    final millis = int.tryParse(mStr) ?? DateTime.now().millisecondsSinceEpoch;
    final counter = int.tryParse(cStr) ?? 0;

    return HLC(millis, counter, node);
  }

  @override
  int compareTo(HLC other) {
    if (millis != other.millis) {
      return millis.compareTo(other.millis);
    }
    if (counter != other.counter) {
      return counter.compareTo(other.counter);
    }
    return nodeId.compareTo(other.nodeId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HLC &&
          runtimeType == other.runtimeType &&
          millis == other.millis &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => millis.hashCode ^ counter.hashCode ^ nodeId.hashCode;
}
