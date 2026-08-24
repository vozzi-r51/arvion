import '../../core/database/db_helper.dart';

class AIEngine {
  final int companyId;
  AIEngine(this.companyId);

  Future<String> processQuery(String query) async {
    final lowerQuery = query.toLowerCase();

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

    // Receivables (Who owes me?)
    if (_matches(lowerQuery, ['owe', 'receivable', 'udhaar', 'paisa lena', 'customer balance'])) {
      final receivables = await DBHelper.instance.getReceivables(companyId);
      if (receivables.isEmpty) return "Mashallah, kisi customer se koi udhaar nahi lena.";
      final top = receivables.first;
      final total = receivables.fold(0.0, (sum, r) => sum + (r['current_balance'] as num));
      return "Total receivables Rs. ${total.toStringAsFixed(0)} hain. Sabse zyada udhaar ${top['name']} ka hai (Rs. ${top['current_balance']}).";
    }

    // Expenses
    if (_matches(lowerQuery, ['expense', 'kharcha', 'kharchay'])) {
      final total = await DBHelper.instance.getTodaysExpensesTotal(companyId);
      return "Aaj ke total kharchay Rs. ${total.toStringAsFixed(0)} hain.";
    }

    // Profit
    if (_matches(lowerQuery, ['profit', 'munafa', 'kamai'])) {
      final total = await DBHelper.instance.getTodaysProfit(companyId);
      return "Aaj ka estimated munafa Rs. ${total.toStringAsFixed(0)} hai.";
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
