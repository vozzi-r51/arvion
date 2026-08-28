import 'dart:convert';
import '../database/db_helper.dart';
import '../audit/audit_logger.dart';

/// Central Recurring Sales / Invoice Service.
/// Handles due template detection, user confirmation review, sale generation via insertSaleWithItems(),
/// frequency schedule advancement, and safe template duplication.
class RecurringSalesService {
  RecurringSalesService._();

  /// Detects active recurring sale templates that are due today or past due.
  static Future<List<Map<String, dynamic>>> getDueRecurringSaleTemplates(
      int companyId) async {
    final db = await DBHelper.instance.database;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await db.query(
      'recurring_templates',
      where:
          'company_id = ? AND type = "sale" AND active = 1 AND next_due_date <= ?',
      whereArgs: [companyId, todayStr],
      orderBy: 'next_due_date ASC',
    );

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Confirms and generates a Sale transaction from a due recurring template.
  /// Calls DBHelper.instance.insertSaleWithItems() so stock, accounting, and customer ledger update atomically.
  static Future<int> generateSaleFromTemplate(
      Map<String, dynamic> template) async {
    final companyId = template['company_id'] as int;
    final customerId = template['customer_id'] as int?;
    final lineItemsJson = template['line_items'] as String?;

    if (customerId == null) {
      throw FormatException('Recurring invoice requires a selected Customer.');
    }

    if (lineItemsJson == null || lineItemsJson.isEmpty) {
      throw FormatException(
          'Recurring invoice requires at least one line item.');
    }

    final List<dynamic> decodedItems = jsonDecode(lineItemsJson);
    if (decodedItems.isEmpty) {
      throw FormatException('Recurring invoice line items cannot be empty.');
    }

    final db = await DBHelper.instance.database;

    // Validate that all products exist in DB
    final List<Map<String, dynamic>> saleItems = [];
    double calculatedSubtotal = 0.0;

    for (final rawItem in decodedItems) {
      final productId = (rawItem['product_id'] as num).toInt();
      final qty = (rawItem['quantity'] as num).toDouble();
      final price = (rawItem['unit_price'] as num).toDouble();

      final prodRows = await db.query(
        'products',
        columns: ['id', 'name'],
        where: 'id = ? AND company_id = ?',
        whereArgs: [productId, companyId],
        limit: 1,
      );

      if (prodRows.isEmpty) {
        throw FormatException(
            'Product #$productId is no longer available in inventory.');
      }

      calculatedSubtotal += qty * price;

      saleItems.add({
        'product_id': productId,
        'quantity': qty,
        'price': price,
        'unit_price': price,
        'total': qty * price,
      });
    }

    final taxPercent = (template['tax_percent'] as num?)?.toDouble() ?? 0.0;
    final discountAmount =
        (template['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final taxAmount =
        (calculatedSubtotal - discountAmount) * (taxPercent / 100.0);
    final netTotal = calculatedSubtotal - discountAmount + taxAmount;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // Call existing insertSaleWithItems pipeline for atomic stock + accounting + customer ledger updates
    final saleId = await DBHelper.instance.insertSaleWithItems(
      sale: {
        'company_id': companyId,
        'customer_id': customerId,
        'sale_date': todayStr,
        'total_amount': netTotal,
        'subtotal': calculatedSubtotal,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'paid_amount': 0.0, // On credit / unpaid invoice
        'status': 'completed',
        'notes': 'Recurring Invoice: ${template['category']}',
        'created_at': DateTime.now().toIso8601String(),
      },
      items: saleItems,
    );

    // Advance next_due_date to next cycle and set last_generated_at
    final currentDue = template['next_due_date'] as String;
    final frequency = template['frequency'] as String? ?? 'monthly';
    final nextDue = calculateNextDueDate(currentDue, frequency);

    await db.update(
      'recurring_templates',
      {
        'next_due_date': nextDue,
        'last_generated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [template['id']],
    );

    await AuditLogger.log(
      companyId: companyId,
      module: 'RecurringSales',
      action: 'generate_invoice',
      description:
          'Generated recurring invoice Sale #$saleId from template "${template['category']}". Next due: $nextDue',
      afterValue: {'sale_id': saleId, 'next_due_date': nextDue},
    );

    return saleId;
  }

  /// Calculates next due date based on frequency.
  static String calculateNextDueDate(
      String currentDueDateStr, String frequency) {
    DateTime dt;
    try {
      dt = DateTime.parse(currentDueDateStr);
    } catch (_) {
      dt = DateTime.now();
    }

    switch (frequency.toLowerCase()) {
      case 'daily':
        dt = dt.add(const Duration(days: 1));
        break;
      case 'weekly':
        dt = dt.add(const Duration(days: 7));
        break;
      case 'yearly':
        dt = DateTime(dt.year + 1, dt.month, dt.day);
        break;
      case 'monthly':
      default:
        // +1 month handling month-end bounds
        int nextMonth = dt.month + 1;
        int nextYear = dt.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        int maxDays = DateTime(nextYear, nextMonth + 1, 0).day;
        int day = dt.day > maxDays ? maxDays : dt.day;
        dt = DateTime(nextYear, nextMonth, day);
        break;
    }

    return dt.toIso8601String().substring(0, 10);
  }

  /// Duplicates a recurring template configuration without duplicating runtime state.
  static Map<String, dynamic> prepareDuplicateTemplate(
      Map<String, dynamic> template) {
    return {
      'company_id': template['company_id'],
      'type': template['type'],
      'category': '${template['category']} (Copy)',
      'amount': template['amount'],
      'frequency': template['frequency'],
      'next_due_date': DateTime.now().toIso8601String().substring(0, 10),
      'active': 1,
      'customer_id': template['customer_id'],
      'line_items': template['line_items'],
      'tax_percent': template['tax_percent'] ?? 0.0,
      'discount_amount': template['discount_amount'] ?? 0.0,
      'last_generated_at': null, // Clear runtime state
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
