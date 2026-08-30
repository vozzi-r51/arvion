import 'base_repository.dart';
import '../database/db_helper.dart';

/// Repository managing multi-warehouse stock locations and inter-warehouse stock transfers.
class WarehouseRepository extends BaseRepository {
  WarehouseRepository();

  /// Create a new warehouse / stock location.
  Future<int> createWarehouse({
    required int companyId,
    required String name,
    String? location,
    int? branchId,
  }) async {
    return await DBHelper.instance.insertWarehouse({
      'company_id': companyId,
      'branch_id': branchId,
      'name': name,
      'location': location,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get active warehouses for a company.
  Future<List<Map<String, dynamic>>> getWarehouses(int companyId) async {
    return await DBHelper.instance.getWarehouses(companyId);
  }

  /// Transfer stock between two warehouses while keeping total company stock invariant.
  Future<bool> transferStock({
    required int companyId,
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required double quantity,
    int? batchId,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Transfer quantity must be greater than zero.');
    }
    if (fromWarehouseId == toWarehouseId) {
      throw ArgumentError('Source and destination warehouses cannot be the same.');
    }

    final db = await DBHelper.instance.database;
    return await db.transaction<bool>((txn) async {
      // 1. Check stock in source batch / location
      if (batchId != null) {
        final bRows = await txn.query(
          'stock_batches',
          where: 'id = ? AND warehouse_id = ?',
          whereArgs: [batchId, fromWarehouseId],
        );
        if (bRows.isEmpty) {
          throw StateError('Batch $batchId not found in source warehouse.');
        }
        final double srcQty = (bRows.first['current_qty'] as num).toDouble();
        if (srcQty < quantity) {
          throw StateError(
              'Insufficient batch stock ($srcQty) for transfer of $quantity.');
        }

        // Deduct from source batch
        await txn.rawUpdate(
          'UPDATE stock_batches SET current_qty = current_qty - ? WHERE id = ?',
          [quantity, batchId],
        );

        // Add to or create destination batch
        final batchNum = bRows.first['batch_number'] as String;
        final mfg = bRows.first['mfg_date'] as String?;
        final exp = bRows.first['expiry_date'] as String?;
        final cost = (bRows.first['cost_price'] as num).toDouble();

        final destBatchRows = await txn.query(
          'stock_batches',
          where:
              'company_id = ? AND product_id = ? AND warehouse_id = ? AND batch_number = ?',
          whereArgs: [companyId, productId, toWarehouseId, batchNum],
        );

        if (destBatchRows.isNotEmpty) {
          final destBatchId = destBatchRows.first['id'] as int;
          await txn.rawUpdate(
            'UPDATE stock_batches SET current_qty = current_qty + ? WHERE id = ?',
            [quantity, destBatchId],
          );
        } else {
          await txn.insert('stock_batches', {
            'company_id': companyId,
            'product_id': productId,
            'warehouse_id': toWarehouseId,
            'batch_number': batchNum,
            'mfg_date': mfg,
            'expiry_date': exp,
            'cost_price': cost,
            'current_qty': quantity,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 2. Record stock movement
      await txn.insert('stock_movements', {
        'company_id': companyId,
        'product_id': productId,
        'from_warehouse_id': fromWarehouseId,
        'to_warehouse_id': toWarehouseId,
        'batch_id': batchId,
        'quantity': quantity,
        'movement_type': 'TRANSFER',
        'reference_type': 'INTER_WAREHOUSE_TRANSFER',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    });
  }

  /// Stage 1 of Stock Transfer Order (STO): Dispatch stock from source warehouse (status = 'IN_TRANSIT').
  Future<int> dispatchTransfer({
    required int companyId,
    required int productId,
    required int sourceWarehouseId,
    required int destWarehouseId,
    required double quantity,
    required String transferNumber,
    int? batchId,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Transfer quantity must be greater than zero.');
    }
    if (sourceWarehouseId == destWarehouseId) {
      throw ArgumentError('Source and destination warehouses cannot be the same.');
    }

    final db = await DBHelper.instance.database;
    return await db.transaction<int>((txn) async {
      if (batchId != null) {
        final bRows = await txn.query(
          'stock_batches',
          where: 'id = ? AND warehouse_id = ?',
          whereArgs: [batchId, sourceWarehouseId],
        );
        if (bRows.isEmpty) {
          throw StateError('Batch $batchId not found in source warehouse.');
        }
        final double srcQty = (bRows.first['current_qty'] as num).toDouble();
        if (srcQty < quantity) {
          throw StateError(
              'Insufficient batch stock ($srcQty) for transfer dispatch of $quantity.');
        }

        await txn.rawUpdate(
          'UPDATE stock_batches SET current_qty = current_qty - ? WHERE id = ?',
          [quantity, batchId],
        );
      }

      final transferId = await txn.insert('stock_transfers', {
        'company_id': companyId,
        'source_warehouse_id': sourceWarehouseId,
        'dest_warehouse_id': destWarehouseId,
        'product_id': productId,
        'batch_id': batchId,
        'quantity': quantity,
        'transfer_number': transferNumber,
        'status': 'IN_TRANSIT',
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.insert('stock_movements', {
        'company_id': companyId,
        'product_id': productId,
        'from_warehouse_id': sourceWarehouseId,
        'batch_id': batchId,
        'quantity': quantity,
        'movement_type': 'TRANSFER_DISPATCH',
        'reference_type': 'STOCK_TRANSFER',
        'reference_id': transferId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return transferId;
    });
  }

  /// Stage 2 of Stock Transfer Order (STO): Receive stock in destination warehouse (status = 'COMPLETED').
  Future<bool> receiveTransfer({
    required int companyId,
    required int transferId,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.transaction<bool>((txn) async {
      final tRows = await txn.query(
        'stock_transfers',
        where: 'id = ? AND company_id = ? AND status = ?',
        whereArgs: [transferId, companyId, 'IN_TRANSIT'],
      );

      if (tRows.isEmpty) {
        throw StateError('Stock transfer $transferId is not in IN_TRANSIT status.');
      }

      final transfer = tRows.first;
      final productId = transfer['product_id'] as int;
      final toWarehouseId = transfer['dest_warehouse_id'] as int;
      final quantity = (transfer['quantity'] as num).toDouble();
      final batchId = transfer['batch_id'] as int?;

      if (batchId != null) {
        final bRows = await txn.query(
          'stock_batches',
          where: 'id = ?',
          whereArgs: [batchId],
        );

        if (bRows.isNotEmpty) {
          final batchNum = bRows.first['batch_number'] as String;
          final mfg = bRows.first['mfg_date'] as String?;
          final exp = bRows.first['expiry_date'] as String?;
          final cost = (bRows.first['cost_price'] as num).toDouble();

          final destBatchRows = await txn.query(
            'stock_batches',
            where:
                'company_id = ? AND product_id = ? AND warehouse_id = ? AND batch_number = ?',
            whereArgs: [companyId, productId, toWarehouseId, batchNum],
          );

          if (destBatchRows.isNotEmpty) {
            final destBatchId = destBatchRows.first['id'] as int;
            await txn.rawUpdate(
              'UPDATE stock_batches SET current_qty = current_qty + ? WHERE id = ?',
              [quantity, destBatchId],
            );
          } else {
            await txn.insert('stock_batches', {
              'company_id': companyId,
              'product_id': productId,
              'warehouse_id': toWarehouseId,
              'batch_number': batchNum,
              'mfg_date': mfg,
              'expiry_date': exp,
              'cost_price': cost,
              'current_qty': quantity,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      await txn.rawUpdate(
        "UPDATE stock_transfers SET status = 'COMPLETED' WHERE id = ?",
        [transferId],
      );

      await txn.insert('stock_movements', {
        'company_id': companyId,
        'product_id': productId,
        'to_warehouse_id': toWarehouseId,
        'batch_id': batchId,
        'quantity': quantity,
        'movement_type': 'TRANSFER_RECEIVE',
        'reference_type': 'STOCK_TRANSFER',
        'reference_id': transferId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    });
  }
}
