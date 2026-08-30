import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuditDiffer {
  /// Generates a structured JSON diff of altered fields between two states.
  static Map<String, dynamic> computeDiff({
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) {
    final Map<String, dynamic> diff = {};
    final allKeys = {...before.keys, ...after.keys};

    for (final key in allKeys) {
      final valBefore = before[key];
      final valAfter = after[key];

      if (valBefore != valAfter) {
        diff[key] = {
          'from': valBefore,
          'to': valAfter,
        };
      }
    }
    return diff;
  }

  /// Calculates the cryptographic SHA-256 hash for the audit record.
  static String calculateAuditHash({
    required String auditId,
    required String diffJson,
    required String previousHash,
  }) {
    final raw = '$auditId|$diffJson|$previousHash';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Verifies the Merkle hash chain of a list of audit records.
  /// Returns false if any audit record or chain link has been tampered with.
  static bool verifyAuditChain(List<Map<String, dynamic>> auditLogs) {
    if (auditLogs.isEmpty) return true;

    String expectedPrevHash =
        '0000000000000000000000000000000000000000000000000000000000000000';

    for (final log in auditLogs) {
      final String auditId = log['audit_id'] as String;
      final String diffPayload = log['diff_payload'] as String;
      final String prevHash = log['previous_audit_hash'] as String;
      final String currentHash = log['audit_hash'] as String;

      if (prevHash != expectedPrevHash) {
        return false; // Chain link broken!
      }

      final computed = calculateAuditHash(
        auditId: auditId,
        diffJson: diffPayload,
        previousHash: prevHash,
      );

      if (computed != currentHash) {
        return false; // Hash mismatch! Payload tampered!
      }

      expectedPrevHash = currentHash;
    }

    return true;
  }
}
