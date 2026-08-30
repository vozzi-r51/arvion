import 'dart:math';

/// Hybrid Logical Clock (HLC) maintaining physical wall-clock time and
/// monotonic counter for causal order across distributed peer nodes.
class HLC implements Comparable<HLC> {
  final int physicalTimeMillis;
  final int counter;
  final String nodeId;

  static int _lastPhysicalTime = 0;
  static int _lastCounter = 0;

  const HLC(this.physicalTimeMillis, this.counter, this.nodeId);

  /// Generate HLC for local event
  static HLC now(String nodeId) {
    final phys = DateTime.now().millisecondsSinceEpoch;
    if (phys > _lastPhysicalTime) {
      _lastPhysicalTime = phys;
      _lastCounter = 0;
    } else {
      _lastCounter++;
    }
    return HLC(_lastPhysicalTime, _lastCounter, nodeId);
  }

  /// Update clock on local send event
  static HLC send(String nodeId) => now(nodeId);

  /// Update clock on receiving a remote message with [remoteHlc]
  static HLC recv(HLC remoteHlc, String nodeId) {
    final phys = DateTime.now().millisecondsSinceEpoch;
    final maxPhys = max(phys, max(_lastPhysicalTime, remoteHlc.physicalTimeMillis));

    if (maxPhys == _lastPhysicalTime && maxPhys == remoteHlc.physicalTimeMillis) {
      _lastCounter = max(_lastCounter, remoteHlc.counter) + 1;
    } else if (maxPhys == _lastPhysicalTime) {
      _lastCounter++;
    } else if (maxPhys == remoteHlc.physicalTimeMillis) {
      _lastCounter = remoteHlc.counter + 1;
    } else {
      _lastCounter = 0;
    }

    _lastPhysicalTime = maxPhys;
    return HLC(_lastPhysicalTime, _lastCounter, nodeId);
  }

  /// Format as ISO-8601 string tuple: "YYYY-MM-DDTHH:mm:ss.sssZ:CCCC:nodeId"
  @override
  String toString() {
    final iso = DateTime.fromMillisecondsSinceEpoch(physicalTimeMillis, isUtc: true)
        .toIso8601String();
    final cStr = counter.toString().padLeft(4, '0');
    return '$iso:$cStr:$nodeId';
  }

  /// Parse string back to HLC object
  static HLC parse(String formatted) {
    final parts = formatted.split(':');
    if (parts.length < 4) {
      // Fallback
      return HLC(DateTime.now().millisecondsSinceEpoch, 0, 'node');
    }
    final isoStr = '${parts[0]}:${parts[1]}:${parts[2]}';
    final phys = DateTime.tryParse(isoStr)?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
    final counter = int.tryParse(parts[3]) ?? 0;
    final node = parts.sublist(4).join(':');
    return HLC(phys, counter, node);
  }

  @override
  int compareTo(HLC other) {
    if (physicalTimeMillis != other.physicalTimeMillis) {
      return physicalTimeMillis.compareTo(other.physicalTimeMillis);
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
          physicalTimeMillis == other.physicalTimeMillis &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode =>
      physicalTimeMillis.hashCode ^ counter.hashCode ^ nodeId.hashCode;
}
