import 'dart:convert';
import '../database/db_helper.dart';

/// E-commerce Channel Sync Service (Daraz Store API & WhatsApp Business Catalog).
class EcommerceChannelService {
  EcommerceChannelService._();
  static final EcommerceChannelService instance = EcommerceChannelService._();

  /// Generates a CSV file payload formatted specifically for WhatsApp Business Catalog upload.
  /// Format: id, title, description, availability, condition, price, link, image_link, brand
  static Future<String> generateWhatsAppCatalogCsv(int companyId) async {
    final products = await DBHelper.instance.getProducts(companyId);
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('id,title,description,availability,condition,price,link,image_link,brand');

    for (final p in products) {
      final stock = (p['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final id = 'SKU-${p['id']}';
      final title = '"${(p['name'] ?? 'Product #${p['id']}').toString().replaceAll('"', '""')}"';
      final desc = '"${(p['description'] ?? 'Quality product from ARVION Store').toString().replaceAll('"', '""')}"';
      final avail = stock > 0 ? 'in stock' : 'out of stock';
      final price = '${(p['sale_price'] as num?)?.toDouble() ?? 0.0} PKR';
      final img = p['image_path'] ?? '';

      buffer.writeln('$id,$title,$desc,$avail,new,$price,,$img,ARVION Store');
    }

    return buffer.toString();
  }

  /// Fetch connected E-commerce Channels for a company.
  static Future<List<Map<String, dynamic>>> listChannels(int companyId) async {
    final db = await DBHelper.instance.database;
    return await db.query(
      'ecommerce_channels',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
  }

  /// Add or update an E-commerce Channel (e.g., Daraz or WhatsApp Catalog).
  static Future<int> saveChannel({
    required int companyId,
    required String channelType, // 'daraz', 'whatsapp', 'shopify'
    required String channelName,
    String? apiKey,
    String? phoneNumber,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('ecommerce_channels', {
      'company_id': companyId,
      'channel_type': channelType,
      'channel_name': channelName,
      'api_key': apiKey,
      'phone_number': phoneNumber,
      'is_active': 1,
      'last_synced_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch pending orders received from Daraz / WhatsApp.
  static Future<List<Map<String, dynamic>>> listChannelOrders(int companyId) async {
    final db = await DBHelper.instance.database;
    return await db.query(
      'channel_orders',
      where: 'company_id = ? AND status = "pending"',
      whereArgs: [companyId],
      orderBy: 'id DESC',
    );
  }

  /// Simulated order webhook / sync from Daraz.
  static Future<void> simulateSyncDarazOrder({
    required int companyId,
    required int channelId,
    required String darazOrderId,
    required String customerName,
    required String customerPhone,
    required double totalAmount,
  }) async {
    final db = await DBHelper.instance.database;
    await db.insert('channel_orders', {
      'company_id': companyId,
      'channel_id': channelId,
      'external_order_id': darazOrderId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'status': 'pending',
      'order_data': jsonEncode({'source': 'Daraz Pakistan'}),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
