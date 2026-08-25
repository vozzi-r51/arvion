import '../../core/database/db_helper.dart';
import '../../core/auth/session.dart';

/// Represents the possible business intents the AI can handle.
/// This matches standard "Tool Calling" patterns in modern LLMs.
enum AIIntent {
  getSales,
  getLowStock,
  getReceivables,
  getExpenses,
  getProfit,
  getPurchases,
  getSupplierCount,
  getProductCount,
  unknown
}

/// Abstract base for a "Business Tool" that the AI can execute.
abstract class AIBusinessTool {
  final int companyId;
  AIBusinessTool(this.companyId);

  bool get requiresOwner => true;
  Future<String> execute(Map<String, dynamic> params);
}

// --- CONCRETE TOOL IMPLEMENTATIONS ---

class SalesTool extends AIBusinessTool {
  SalesTool(super.companyId);
  @override
  bool get requiresOwner => false; // Cashiers can see sales

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysSalesTotal(companyId);
    return "Aaj ki total sales Rs. ${total.toStringAsFixed(0)} hain.";
  }
}

class StockTool extends AIBusinessTool {
  StockTool(super.companyId);
  @override
  bool get requiresOwner => false;

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await DBHelper.instance.getLowStockCount(companyId);
    if (count == 0) return "Sab products ka stock theek hai. Koi bhi low stock par nahi hai.";
    return "Aapke $count products low stock par hain. Inhein reorder karne ki zaroorat ho sakti hai.";
  }
}

class ReceivablesTool extends AIBusinessTool {
  ReceivablesTool(super.companyId);
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final receivables = await DBHelper.instance.getReceivables(companyId);
    if (receivables.isEmpty) return "Mashallah, kisi customer se koi udhaar nahi lena.";
    final top = receivables.first;
    final total = receivables.fold(0.0, (sum, r) => sum + (r['current_balance'] as num));
    return "Total receivables Rs. ${total.toStringAsFixed(0)} hain. Sabse zyada udhaar ${top['name']} ka hai (Rs. ${top['current_balance']}).";
  }
}

class ExpensesTool extends AIBusinessTool {
  ExpensesTool(super.companyId);
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysExpensesTotal(companyId);
    return "Aaj ke total kharchay Rs. ${total.toStringAsFixed(0)} hain.";
  }
}

class ProfitTool extends AIBusinessTool {
  ProfitTool(super.companyId);
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysProfit(companyId);
    return "Aaj ka estimated munafa Rs. ${total.toStringAsFixed(0)} hai.";
  }
}

class PurchasesTool extends AIBusinessTool {
  PurchasesTool(super.companyId);
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysPurchaseTotal(companyId);
    return "Aaj ki total purchase Rs. ${total.toStringAsFixed(0)} hai.";
  }
}

class SupplierCountTool extends AIBusinessTool {
  SupplierCountTool(super.companyId);
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await DBHelper.instance.getSupplierCount(companyId);
    return "Aapke total $count suppliers hain.";
  }
}

class ProductCountTool extends AIBusinessTool {
  ProductCountTool(super.companyId);
  @override
  bool get requiresOwner => false;
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await DBHelper.instance.getProductCount(companyId);
    return "Aapki shop mein total $count products listed hain.";
  }
}

/// The Orchestrator that manages Intent resolution and Tool execution.
class AIEngine {
  final int companyId;
  final Map<AIIntent, AIBusinessTool> _registry;

  AIEngine(this.companyId) : _registry = {
    AIIntent.getSales: SalesTool(companyId),
    AIIntent.getLowStock: StockTool(companyId),
    AIIntent.getReceivables: ReceivablesTool(companyId),
    AIIntent.getExpenses: ExpensesTool(companyId),
    AIIntent.getProfit: ProfitTool(companyId),
    AIIntent.getPurchases: PurchasesTool(companyId),
    AIIntent.getSupplierCount: SupplierCountTool(companyId),
    AIIntent.getProductCount: ProductCountTool(companyId),
  };

  Future<String> processQuery(String query) async {
    final intent = _resolveIntentOffline(query);
    
    if (intent == AIIntent.unknown) {
      return "Maaf kijiye, main ye samajh nahi saka. Aap sales, stock, udhaar ya kharchon ke baray mein pooch sakte hain. (Try: 'aaj ki sale' or 'low stock items')";
    }

    final tool = _registry[intent];
    if (tool == null) return "System Error: Tool not found.";

    // RBAC Check
    if (tool.requiresOwner && !Session.isOwner) {
      return "Maaf kijiye, aapko ye maloomat dekhne ki ijazat nahi hai.";
    }

    return await tool.execute({});
  }

  /// Current keyword-based resolver. 
  /// This is structured so it can be swapped for an LLM-based resolver easily.
  AIIntent _resolveIntentOffline(String query) {
    final q = query.toLowerCase();

    if (_matches(q, ['today', 'aj', 'aaj', 'sales', 'sale', 'فروخت', 'سیلز', 'آج'])) {
      return AIIntent.getSales;
    }
    if (_matches(q, ['low stock', 'stock kam', 'inventory kam', 'out of stock', 'سٹاک', 'انوینٹری'])) {
      return AIIntent.getLowStock;
    }
    if (_matches(q, ['owe', 'receivable', 'udhaar', 'paisa lena', 'customer balance', 'ادھار', 'وصولی'])) {
      return AIIntent.getReceivables;
    }
    if (_matches(q, ['expense', 'kharcha', 'kharchay', 'اخراجات', 'خرچہ'])) {
      return AIIntent.getExpenses;
    }
    if (_matches(q, ['profit', 'munafa', 'kamai', 'منافع', 'کمائی'])) {
      return AIIntent.getProfit;
    }
    if (_matches(q, ['purchase', 'kharidari', 'maal kharida', 'خریداری'])) {
      return AIIntent.getPurchases;
    }
    if (_matches(q, ['supplier', 'vendor', 'سپلائر'])) {
      return AIIntent.getSupplierCount;
    }
    if (_matches(q, ['total product', 'kitne product', 'total items', 'آئٹم'])) {
      return AIIntent.getProductCount;
    }

    return AIIntent.unknown;
  }

  bool _matches(String query, List<String> keywords) {
    for (var k in keywords) {
      if (query.contains(k)) return true;
    }
    return false;
  }
}
