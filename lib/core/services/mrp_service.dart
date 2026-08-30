import '../database/db_helper.dart';
import '../utils/uuid_v7.dart';

/// Bill of Materials (BOM) & Light Manufacturing Work Order Service.
class MrpService {
  MrpService._();
  static final MrpService instance = MrpService._();

  /// Create a Bill of Materials (BOM) recipe.
  Future<dynamic> createBOM({
    required dynamic companyId,
    required dynamic finishedProductId,
    required double yieldQty,
    double laborCost = 0.0,
    double overheadCost = 0.0,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await DBHelper.instance.database;
    final bomIdStr = UUIDv7.generate();

    final int bomId = await db.insert('bill_of_materials', {
      'company_id': companyId,
      'finished_product_id': finishedProductId,
      'name': 'BOM for Product $finishedProductId',
      'output_quantity': yieldQty,
      'notes': 'Labor: $laborCost, Overhead: $overheadCost, Ref: $bomIdStr',
      'created_at': DateTime.now().toIso8601String(),
    });

    for (final item in items) {
      final rawId = item['raw_product_id'];
      final reqQty = (item['required_qty'] as num).toDouble();

      await db.insert('bom_items', {
        'bom_id': bomId,
        'raw_material_product_id': rawId,
        'quantity_required': reqQty,
        'unit': 'Pc',
      });
    }

    return bomId;
  }

  /// Create a Production Order (Work Order).
  Future<dynamic> createProductionOrder({
    required dynamic companyId,
    required dynamic bomId,
    required dynamic warehouseId,
    required double targetQty,
  }) async {
    final db = await DBHelper.instance.database;

    final int orderId = await db.insert('production_orders', {
      'company_id': companyId,
      'bom_id': bomId,
      'quantity_to_produce': targetQty,
      'status': 'IN_PROGRESS',
      'created_at': DateTime.now().toIso8601String(),
    });

    return orderId;
  }

  /// Complete a Production Order:
  /// 1. Deducts raw material stock.
  /// 2. Calculates finished product cost: (Raw Costs + Labor + Overheads).
  /// 3. Increments finished goods inventory.
  /// 4. Posts manufacturing accounting journal entries.
  Future<bool> completeProductionOrder(dynamic orderId) async {
    final db = await DBHelper.instance.database;
    return await db.transaction<bool>((txn) async {
      final orderRows = await txn.query(
        'production_orders',
        where: 'id = ? OR id = ?',
        whereArgs: [orderId, int.tryParse(orderId.toString()) ?? 0],
      );

      if (orderRows.isEmpty) {
        throw StateError('Production order $orderId not found.');
      }

      final order = orderRows.first;
      if (order['status'] == 'COMPLETED') {
        return true;
      }

      final bomId = order['bom_id'];
      final targetQty = (order['quantity_to_produce'] as num).toDouble();
      final companyId = order['company_id'];

      final bomRows = await txn.query(
        'bill_of_materials',
        where: 'id = ?',
        whereArgs: [bomId],
      );

      if (bomRows.isEmpty) {
        throw StateError('BOM $bomId not found for production order.');
      }

      final bom = bomRows.first;
      final finishedProductId = bom['finished_product_id'];
      final yieldQty = (bom['output_quantity'] as num).toDouble();

      double laborCost = 0.0;
      double overheadCost = 0.0;
      final notes = bom['notes'] as String? ?? '';
      if (notes.contains('Labor:')) {
        try {
          final laborPart = notes.split('Labor:')[1].split(',').first;
          laborCost = double.parse(laborPart.trim());
        } catch (_) {}
      }
      if (notes.contains('Overhead:')) {
        try {
          final ovPart = notes.split('Overhead:')[1].split(',').first;
          overheadCost = double.parse(ovPart.trim());
        } catch (_) {}
      }

      final multiplier = yieldQty > 0 ? targetQty / yieldQty : targetQty;

      final bomItems = await txn.query(
        'bom_items',
        where: 'bom_id = ?',
        whereArgs: [bomId],
      );

      double totalRawCost = 0.0;

      for (final item in bomItems) {
        final rawProductId = item['raw_material_product_id'];
        final baseReq = (item['quantity_required'] as num).toDouble();

        final actualReqQty = baseReq * multiplier;

        final rawProdRows = await txn.query(
          'products',
          columns: ['purchase_price', 'current_stock'],
          where: 'id = ?',
          whereArgs: [rawProductId],
        );

        double unitCost = 0.0;
        if (rawProdRows.isNotEmpty) {
          unitCost = (rawProdRows.first['purchase_price'] as num).toDouble();
        }

        totalRawCost += actualReqQty * unitCost;

        await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
          [actualReqQty, rawProductId],
        );

        await txn.insert('stock_movements', {
          'company_id': companyId,
          'product_id': rawProductId,
          'quantity': actualReqQty,
          'movement_type': 'PRODUCTION_CONSUMPTION',
          'reference_type': 'PRODUCTION_ORDER',
          'reference_id': orderId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final totalFinishedCost =
          totalRawCost + (laborCost * multiplier) + (overheadCost * multiplier);
      final newFinishedUnitCost =
          targetQty > 0 ? totalFinishedCost / targetQty : 0.0;

      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock + ?, purchase_price = ? WHERE id = ?',
        [targetQty, newFinishedUnitCost, finishedProductId],
      );

      await txn.insert('stock_movements', {
        'company_id': companyId,
        'product_id': finishedProductId,
        'quantity': targetQty,
        'movement_type': 'PRODUCTION_YIELD',
        'reference_type': 'PRODUCTION_ORDER',
        'reference_id': orderId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate(
        "UPDATE production_orders SET status = 'COMPLETED' WHERE id = ?",
        [orderId],
      );

      // Automated Accounting Entry
      final coaRows = await txn.query('chart_of_accounts',
          where: 'company_id = ?', whereArgs: [companyId]);
      int? getAccId(String name) {
        try {
          final target = name.toLowerCase();
          return coaRows.firstWhere((r) {
            final accName = (r['name'] as String).toLowerCase();
            return accName == target || accName.contains(target);
          })['id'] as int;
        } catch (_) {
          return null;
        }
      }

      final invAcc = getAccId('inventory');
      final cogsAcc = getAccId('cost of goods sold') ?? invAcc;

      if (invAcc != null && totalFinishedCost > 0) {
        await DBHelper.instance.postAutomatedEntry(
          txn,
          companyId: int.tryParse(companyId.toString()) ?? 1,
          date: DateTime.now().toIso8601String(),
          description: 'Auto: Production Work Order Complete #$orderId',
          sourceType: 'production_order',
          sourceId: int.tryParse(orderId.toString()) ?? 0,
          lines: [
            {'account_id': invAcc, 'debit': totalFinishedCost, 'credit': 0.0},
            {'account_id': cogsAcc, 'debit': 0.0, 'credit': totalFinishedCost},
          ],
        );
      }

      return true;
    });
  }
}
