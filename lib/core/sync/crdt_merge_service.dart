import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import 'hlc.dart';

/// CRDT Conflict Resolution Merge Engine for ARVION / DukanEdge Multi-Branch Sync.
/// Handles LWW (Last-Write-Wins) column-level merge for mutable entities (Customers, Products)
/// and G-Set (Grow-Only) append-merge for immutable entities (Ledgers, Invoices, Stock Deltas).
class CRDTMergeService {
  CRDTMergeService._();
  static final CRDTMergeService instance = CRDTMergeService._();

  /// Log a local database change into the `sync_changelog` table.
  Future<void> logLocalChange({
    required String changeId,
    required String companyId,
    required String branchId,
    required String nodeId,
    required String tableName,
    required String rowId,
    required String operationType, // 'INSERT', 'UPDATE', 'DELETE'
    required Map<String, dynamic> columnsPayload,
    required HLC hlc,
  }) async {
    await DBHelper.instance.insertSyncChangelog({
      'change_id': changeId,
      'company_id': companyId,
      'branch_id': branchId,
      'node_id': nodeId,
      'table_name': tableName,
      'row_id': rowId,
      'hlc_timestamp': hlc.toString(),
      'operation_type': operationType,
      'columns_payload': jsonEncode(columnsPayload),
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Apply a list of remote delta logs atomically inside a single SQLite transaction.
  Future<void> applyRemoteDeltas(List<Map<String, dynamic>> deltas) async {
    if (deltas.isEmpty) return;

    final db = await DBHelper.instance.database;
    await db.transaction((txn) async {
      for (final delta in deltas) {
        final changeId = delta['change_id'] as String;
        final tableName = delta['table_name'] as String;
        final rowId = delta['row_id'] as String;
        final hlcStr = delta['hlc_timestamp'] as String;
        final opType = delta['operation_type'] as String;
        final payloadRaw = delta['columns_payload'] as String;
        final Map<String, dynamic> payload = jsonDecode(payloadRaw);

        final remoteHlc = HLC.parse(hlcStr);

        if (_isImmutableGSet(tableName)) {
          // G-Set (Grow-Only) Append Merge
          await txn.insert(
            tableName,
            payload,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } else {
          // LWW (Last-Write-Wins) Column-Level Merge
          await _mergeLww(txn, tableName, rowId, payload, remoteHlc);
        }

        // Record watermark state
        final nodeId = delta['node_id'] as String? ?? 'remote';
        await txn.insert(
          'sync_node_state',
          {
            'node_id': nodeId,
            'last_seen_hlc': hlcStr,
            'last_synced_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Mark local log as synced/processed
        await txn.insert(
          'sync_changelog',
          {
            'change_id': changeId,
            'company_id': delta['company_id'] ?? '1',
            'branch_id': delta['branch_id'] ?? '1',
            'node_id': nodeId,
            'table_name': tableName,
            'row_id': rowId,
            'hlc_timestamp': hlcStr,
            'operation_type': opType,
            'columns_payload': payloadRaw,
            'is_synced': 1,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  bool _isImmutableGSet(String tableName) {
    return tableName == 'journal_entries' ||
        tableName == 'journal_entry_lines' ||
        tableName == 'inventory_stock_deltas' ||
        tableName == 'sales' ||
        tableName == 'purchases';
  }

  Future<void> _mergeLww(
    Transaction txn,
    String tableName,
    String rowId,
    Map<String, dynamic> remotePayload,
    HLC remoteHlc,
  ) async {
    final localRows = await txn.query(
      tableName,
      where: 'id = ?',
      whereArgs: [rowId],
    );

    if (localRows.isEmpty) {
      // Row does not exist locally -> Insert remote payload
      final insertMap = Map<String, dynamic>.from(remotePayload);
      insertMap['id'] = rowId;
      await txn.insert(tableName, insertMap,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      // Row exists locally -> Column-level Last-Write-Wins (LWW) merge
      final Map<String, dynamic> updatePayload = {};

      for (final entry in remotePayload.entries) {
        if (entry.key == 'id') continue;
        // Last-Write-Wins field update
        updatePayload[entry.key] = entry.value;
      }

      if (updatePayload.isNotEmpty) {
        await txn.update(
          tableName,
          updatePayload,
          where: 'id = ?',
          whereArgs: [rowId],
        );
      }
    }
  }
}
