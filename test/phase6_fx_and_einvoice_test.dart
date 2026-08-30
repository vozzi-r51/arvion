import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/accounting/fx_engine.dart';
import 'package:bizmanager/core/compliance/einvoice_signer.dart';
import 'package:bizmanager/core/auth/permission_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 6 Multi-Currency FX Engine & Cryptographic E-Invoicing Tests', () {
    late DBHelper db;
    late int companyId;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'FX & E-Invoice Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) Settling a \$1,000 invoice (booked @ 280 PKR) at a later rate (285 PKR) generates 5,000 PKR Realized FX Gain', () {
      final result = FXEngine.computeRealizedVariance(
        invoiceExchangeRate: 280.0,
        paymentExchangeRate: 285.0,
        foreignPaymentAmount: 1000.0,
      );

      expect(result.basePaymentAmount, 285000.0); // 1000 * 285
      expect(result.fxGainLossAmount, 5000.0); // (285 - 280) * 1000 = 5,000 PKR
      expect(result.isGain, isTrue);
    });

    test('b) Modifying invoice payload invalidates SHA-256 hash and breaks hash chaining', () async {
      final sale1Id = await db.insertSaleWithItems(
        sale: {
          'company_id': companyId,
          'invoice_number': 'INV-CHAIN-001',
          'sale_type': 'cash',
          'subtotal': 1000.0,
          'total_amount': 1000.0,
          'paid_amount': 1000.0,
          'due_amount': 0.0,
          'sale_date': DateTime.now().toIso8601String(),
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        },
        items: [
          {'product_name': 'Original Item', 'quantity': 1.0, 'unit_price': 1000.0, 'total': 1000.0}
        ],
      );

      final sale2Id = await db.insertSaleWithItems(
        sale: {
          'company_id': companyId,
          'invoice_number': 'INV-CHAIN-002',
          'sale_type': 'cash',
          'subtotal': 2000.0,
          'total_amount': 2000.0,
          'paid_amount': 2000.0,
          'due_amount': 0.0,
          'sale_date': DateTime.now().toIso8601String(),
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        },
        items: [
          {'product_name': 'Original Item 2', 'quantity': 2.0, 'unit_price': 1000.0, 'total': 2000.0}
        ],
      );

      expect(sale1Id, isPositive);
      expect(sale2Id, isPositive);

      final dbConn = await db.database;
      final logs = await dbConn.query(
        'einvoice_clearance_logs',
        where: 'company_id = ?',
        whereArgs: [companyId.toString()],
        orderBy: 'invoice_counter ASC',
      );

      expect(logs.length, 2);

      final log1 = logs[0];
      final log2 = logs[1];

      // Verify log2's previous_invoice_hash matches log1's invoice_hash
      expect(log2['previous_invoice_hash'], log1['invoice_hash']);

      // Tamper simulation: Modifying payload alters hash
      final tamperedPayload = (log1['canonical_payload'] as String).replaceAll('1000', '9999');
      final tamperedHash = EInvoiceSigner.computeInvoiceHash('$tamperedPayload|${log1['previous_invoice_hash']}');

      expect(tamperedHash, isNot(equals(log1['invoice_hash'])));
    });

    test('c) TLV QR encoder and decoder unroll Tags 1-7 byte arrays back to exact values', () {
      final seller = 'DukanEdge Global Ltd';
      final vat = 'NTN-3001928-1';
      final ts = '2026-08-30T17:00:00Z';
      final total = '1150.00';
      final vatTotal = '150.00';
      final hash = 'c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2';
      final sig = 'd41d8cd98f00b204e9800998ecf8427e';

      final tlvBase64 = EInvoiceSigner.generateTLVQR(
        sellerName: seller,
        vatNumber: vat,
        timestamp: ts,
        invoiceTotal: total,
        vatTotal: vatTotal,
        invoiceHash: hash,
        digitalSignature: sig,
      );

      expect(tlvBase64.isNotEmpty, isTrue);

      final decodedMap = EInvoiceSigner.decodeTLVQR(tlvBase64);

      expect(decodedMap[1], seller);
      expect(decodedMap[2], vat);
      expect(decodedMap[3], ts);
      expect(decodedMap[4], total);
      expect(decodedMap[5], vatTotal);
      expect(decodedMap[6], hash);
      expect(decodedMap[7], sig);
    });
  });
}
