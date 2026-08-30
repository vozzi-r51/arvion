import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EInvoiceSigner {
  /// Converts a map into a deterministic, key-sorted canonical JSON string.
  static String toCanonicalJson(Map<String, dynamic> payload) {
    final sortedKeys = payload.keys.toList()..sort();
    final Map<String, dynamic> sortedMap = {};
    for (final key in sortedKeys) {
      sortedMap[key] = payload[key];
    }
    return jsonEncode(sortedMap);
  }

  /// Computes deterministic SHA-256 hash of canonical invoice string.
  static String computeInvoiceHash(String canonicalPayload) {
    final bytes = utf8.encode(canonicalPayload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Builds standard Tag-Length-Value (TLV) encoded string for official tax QR code.
  static String generateTLVQR({
    required String sellerName,
    required String vatNumber,
    required String timestamp,
    required String invoiceTotal,
    required String vatTotal,
    required String invoiceHash,
    required String digitalSignature,
  }) {
    final List<int> tlvBytes = [];

    void addTLV(int tag, String value) {
      final valBytes = utf8.encode(value);
      tlvBytes.add(tag);
      tlvBytes.add(valBytes.length);
      tlvBytes.addAll(valBytes);
    }

    addTLV(1, sellerName);
    addTLV(2, vatNumber);
    addTLV(3, timestamp);
    addTLV(4, invoiceTotal);
    addTLV(5, vatTotal);
    addTLV(6, invoiceHash);
    addTLV(7, digitalSignature);

    return base64Encode(Uint8List.fromList(tlvBytes));
  }

  /// Decodes Tag-Length-Value (TLV) Base64 string back into Tag -> String map.
  static Map<int, String> decodeTLVQR(String base64Tlv) {
    final Uint8List bytes = base64Decode(base64Tlv);
    final Map<int, String> result = {};

    int index = 0;
    while (index < bytes.length) {
      final int tag = bytes[index];
      index++;
      if (index >= bytes.length) break;

      final int len = bytes[index];
      index++;
      if (index + len > bytes.length) break;

      final String value = utf8.decode(bytes.sublist(index, index + len));
      result[tag] = value;
      index += len;
    }

    return result;
  }
}
