import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmanager/core/database/db_helper.dart';
import 'package:bizmanager/core/audit/audit_differ.dart';
import 'package:bizmanager/core/workers/batch_worker.dart';
import 'package:bizmanager/core/auth/permission_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DBHelper.instance.closeDatabase();
  });

  group('Phase 7 Enterprise Auditing, Disaster Recovery & Performance Tests', () {
    late DBHelper db;
    late int companyId;

    setUp(() async {
      PermissionService().setActivePermissions({'owner'});
      db = DBHelper.instance;
      companyId = await db.insertCompany({
        'name': 'Phase 7 Audit Co ${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('a) Updating a product captures exact before/after field diffs in audit_vault with valid Merkle hash', () async {
      final productId = await db.insertProduct({
        'company_id': companyId,
        'name': 'Laptop Stand',
        'current_stock': 20.0,
        'purchase_price': 1500.0,
        'retail_price': 2000.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update cost price and retail price
      await db.updateProduct(productId, {
        'purchase_price': 1800.0,
        'retail_price': 2400.0,
      });

      final dbConn = await db.database;
      final auditRows = await dbConn.query(
        'audit_vault',
        where: 'company_id = ? AND entity_id = ?',
        whereArgs: [companyId.toString(), productId.toString()],
      );

      expect(auditRows.isNotEmpty, isTrue);
      final audit = auditRows.first;

      expect(audit['action_type'], 'UPDATE');
      expect(audit['entity_table'], 'products');

      final diffMap = jsonDecode(audit['diff_payload'] as String) as Map<String, dynamic>;
      expect(diffMap.containsKey('purchase_price'), isTrue);
      expect((diffMap['purchase_price']['from'] as num).toDouble(), 1500.0);
      expect((diffMap['purchase_price']['to'] as num).toDouble(), 1800.0);

      // Verify cryptographic SHA-256 Merkle chain
      final computedHash = AuditDiffer.calculateAuditHash(
        auditId: audit['audit_id'] as String,
        diffJson: audit['diff_payload'] as String,
        previousHash: audit['previous_audit_hash'] as String,
      );
      expect(audit['audit_hash'], computedHash);
    });

    test('b) Modifying prior audit log payload breaks the Merkle hash verification chain', () {
      final log1 = {
        'audit_id': 'AUDIT-001',
        'diff_payload': '{"price":{"from":10,"to":20}}',
        'previous_audit_hash': '0000000000000000000000000000000000000000000000000000000000000000',
      };
      log1['audit_hash'] = AuditDiffer.calculateAuditHash(
        auditId: log1['audit_id']!,
        diffJson: log1['diff_payload']!,
        previousHash: log1['previous_audit_hash']!,
      );

      final log2 = {
        'audit_id': 'AUDIT-002',
        'diff_payload': '{"stock":{"from":50,"to":100}}',
        'previous_audit_hash': log1['audit_hash']!,
      };
      log2['audit_hash'] = AuditDiffer.calculateAuditHash(
        auditId: log2['audit_id']!,
        diffJson: log2['diff_payload']!,
        previousHash: log2['previous_audit_hash']!,
      );

      final List<Map<String, dynamic>> chain = [log1, log2];

      // Chain initially valid
      expect(AuditDiffer.verifyAuditChain(chain), isTrue);

      // Tamper simulation: Modify diff_payload of log1
      final tamperedLog1 = Map<String, dynamic>.from(log1);
      tamperedLog1['diff_payload'] = '{"price":{"from":10,"to":9999}}';

      final tamperedChain = [tamperedLog1, log2];

      // Verification fails immediately!
      expect(AuditDiffer.verifyAuditChain(tamperedChain), isFalse);
    });

    test('c) BatchWorker Isolate aggregates trial balance in background thread without UI thread jank', () async {
      final List<Map<String, dynamic>> journalLines = List.generate(
        1000,
        (i) => {
          'account_id': (i % 5) + 1,
          'debit': (i * 10).toDouble(),
          'credit': (i % 2 == 0) ? (i * 5).toDouble() : 0.0,
        },
      );

      final balances = await BatchWorker.aggregateTrialBalance(journalLines);

      expect(balances.length, 5);
      expect(balances.containsKey(1), isTrue);
      expect(balances[1]!['debit'], greaterThan(0));
    });
  });
}
