import '../../core/database/db_helper.dart';
import '../../core/auth/session.dart';

class AIEngine {
  final int companyId;
  AIEngine(this.companyId);

  Future<String> processQuery(String query) async {
    final lowerQuery = query.toLowerCase();
    final isOwner = Session.isOwner;

    // Today's Sales
    if (_matches(lowerQuery, ['today', 'aj', 'aaj', 'sales', 'sale'])) {
      final total = await DBHelper.instance.getTodaysSalesTotal(companyId);
      return "Aaj ki total sales Rs. ${total.toStringAsFixed(0)} hain.";
    }

    // Low Stock
    if (_matches(lowerQuery, ['low stock', 'stock kam', 'inventory kam', 'out of stock'])) {
      final count = await DBHelper.instance.getLowStockCount(companyId);
      if (count == 0) return "Sab products ka stock theek hai. Koi bhi low stock par nahi hai.";
      return "Aapke $count products low stock par hain. Inhein reorder karne ki zaroorat ho sakti hai.";
    }

    // Receivables (Who owes me?) - Restricted to Owner
    if (_matches(lowerQuery, ['owe', 'receivable', 'udhaar', 'paisa lena', 'customer balance'])) {
      if (!isOwner) return "Maaf kijiye, aapko accounts receivable dekhne ki ijazat nahi hai.";
      final receivables = await DBHelper.instance.getReceivables(companyId);
      if (receivables.isEmpty) return "Mashallah, kisi customer se koi udhaar nahi lena.";
      final top = receivables.first;
      final total = receivables.fold(0.0, (sum, r) => sum + (r['current_balance'] as num));
      return "Total receivables Rs. ${total.toStringAsFixed(0)} hain. Sabse zyada udhaar ${top['name']} ka hai (Rs. ${top['current_balance']}).";
    }

    // Expenses - Restricted to Owner
    if (_matches(lowerQuery, ['expense', 'kharcha', 'kharchay'])) {
      if (!isOwner) return "Maaf kijiye, aapko kharchay dekhne ki ijazat nahi hai.";
      final total = await DBHelper.instance.getTodaysExpensesTotal(companyId);
      return "Aaj ke total kharchay Rs. ${total.toStringAsFixed(0)} hain.";
    }

    // Profit - Restricted to Owner
    if (_matches(lowerQuery, ['profit', 'munafa', 'kamai'])) {
      if (!isOwner) return "Maaf kijiye, aapko munafa dekhne ki ijazat nahi hai.";
      final total = await DBHelper.instance.getTodaysProfit(companyId);
      return "Aaj ka estimated munafa Rs. ${total.toStringAsFixed(0)} hai.";
    }

    // Purchases - Restricted to Owner
    if (_matches(lowerQuery, ['purchase', 'kharidari', 'maal kharida'])) {
      if (!isOwner) return "Maaf kijiye, aapko kharidari ka data dekhne ki ijazat nahi hai.";
      final total = await DBHelper.instance.getTodaysPurchaseTotal(companyId);
      return "Aaj ki total purchase Rs. ${total.toStringAsFixed(0)} hai.";
    }

    // Suppliers - Restricted to Owner
    if (_matches(lowerQuery, ['supplier', 'vendor'])) {
      if (!isOwner) return "Maaf kijiye, aapko supplier ka data dekhne ki ijazat nahi hai.";
      final count = await DBHelper.instance.getSupplierCount(companyId);
      return "Aapke total $count suppliers hain.";
    }

    // Counts
    if (_matches(lowerQuery, ['total product', 'kitne product', 'total items'])) {
      final count = await DBHelper.instance.getProductCount(companyId);
      return "Aapki shop mein total $count products listed hain.";
    }

    return "Maaf kijiye, main ye samajh nahi saka. Aap sales, stock, udhaar ya kharchon ke baray mein pooch sakte hain.";
  }

  bool _matches(String query, List<String> keywords) {
    int matches = 0;
    for (var k in keywords) {
      if (query.contains(k)) matches++;
    }
    return matches >= 1;
  }
}
