import 'package:dukanedge/core/database/db_helper.dart';
import 'package:dukanedge/core/auth/session.dart';

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
  createExpense,
  unknown
}

/// Represents a response from the AI, which can be simple text or a pending action.
class AIResponse {
  final String text;
  final AIIntent? pendingIntent;
  final Map<String, dynamic>? params;

  AIResponse(this.text, {this.pendingIntent, this.params});
}

/// Abstract base for a "Business Tool" that the AI can execute.
abstract class AIBusinessTool {
  final int companyId;
  final String locale;
  AIBusinessTool(this.companyId, {this.locale = 'ur'});

  bool get requiresOwner => true;
  Future<String> execute(Map<String, dynamic> params);
  
  bool get isUrdu => locale.startsWith('ur');
}

// --- CONCRETE TOOL IMPLEMENTATIONS ---

class SalesTool extends AIBusinessTool {
  SalesTool(super.companyId, {super.locale});
  @override
  bool get requiresOwner => false; // Cashiers can see sales

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysSalesTotal(companyId);
    return isUrdu 
      ? "Aaj ki total sales Rs. ${total.toStringAsFixed(0)} hain."
      : "Today's total sales are Rs. ${total.toStringAsFixed(0)}.";
  }
}

class StockTool extends AIBusinessTool {
  StockTool(super.companyId, {super.locale});
  @override
  bool get requiresOwner => false;

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await DBHelper.instance.getLowStockCount(companyId);
    if (count == 0) {
      return isUrdu 
        ? "Sab products ka stock theek hai. Koi bhi low stock par nahi hai."
        : "All products are in stock. Nothing is low.";
    }
    return isUrdu
      ? "Aapke $count products low stock par hain. Inhein reorder karne ki zaroorat ho sakti hai."
      : "You have $count products low in stock. You might need to reorder them.";
  }
}

class ReceivablesTool extends AIBusinessTool {
  ReceivablesTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final receivables = await DBHelper.instance.getReceivables(companyId);
    if (receivables.isEmpty) {
      return isUrdu 
        ? "Mashallah, kisi customer se koi udhaar nahi lena."
        : "No receivables. All clear!";
    }
    final top = receivables.first;
    final total = receivables.fold(0.0, (sum, r) => sum + (r['current_balance'] as num));
    return isUrdu
      ? "Total receivables Rs. ${total.toStringAsFixed(0)} hain. Sabse zyada udhaar ${top['name']} ka hai (Rs. ${top['current_balance']})."
      : "Total receivables are Rs. ${total.toStringAsFixed(0)}. Highest is from ${top['name']} (Rs. ${top['current_balance']}).";
  }
}

class ExpensesTool extends AIBusinessTool {
  ExpensesTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysExpensesTotal(companyId);
    return isUrdu
      ? "Aaj ke total kharchay Rs. ${total.toStringAsFixed(0)} hain."
      : "Today's total expenses are Rs. ${total.toStringAsFixed(0)}.";
  }
}

class ProfitTool extends AIBusinessTool {
  ProfitTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final total = await DBHelper.instance.getTodaysProfit(companyId);
    return isUrdu
      ? "Aaj ka estimated munafa Rs. ${total.toStringAsFixed(0)} hai."
      : "Today's estimated profit is Rs. ${total.toStringAsFixed(0)}.";
  }
}

class PurchasesTool extends AIBusinessTool {
  PurchasesTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final db = DBHelper.instance;
    final total = await db.getTodaysPurchaseTotal(companyId);
    return isUrdu
      ? "Aaj ki total purchase Rs. ${total.toStringAsFixed(0)} hai."
      : "Today's total purchase is Rs. ${total.toStringAsFixed(0)}.";
  }
}

class SupplierCountTool extends AIBusinessTool {
  SupplierCountTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await DBHelper.instance.getSupplierCount(companyId);
    return isUrdu
      ? "Aapke total $count suppliers hain."
      : "You have a total of $count suppliers.";
  }
}

class ProductCountTool extends AIBusinessTool {
  ProductCountTool(super.companyId, {super.locale});
  @override
  bool get requiresOwner => false;
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await DBHelper.instance.getProductCount(companyId);
    return isUrdu
      ? "Aapki shop mein total $count products listed hain."
      : "You have a total of $count products listed.";
  }
}

class CreateExpenseTool extends AIBusinessTool {
  CreateExpenseTool(super.companyId, {super.locale});
  
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final amount = params['amount'] as double? ?? 0;
    final category = params['category'] as String? ?? 'Operating Expenses';
    
    if (amount <= 0) {
      return isUrdu 
        ? "Maaf kijiye, expense amount zero se zyada hona chahiye."
        : "Sorry, expense amount must be greater than zero.";
    }

    await DBHelper.instance.insertExpense({
      'company_id': companyId,
      'category': category,
      'amount': amount,
      'expense_date': DateTime.now().toIso8601String(),
      'payment_method': 'Cash',
      'description': 'AI generated expense',
      'created_at': DateTime.now().toIso8601String(),
    });

    return isUrdu
      ? "Theek hai, Rs. ${amount.toStringAsFixed(0)} ka $category kharcha record kar liya gaya hai."
      : "Okay, recorded an expense of Rs. ${amount.toStringAsFixed(0)} for $category.";
  }
}

/// The Orchestrator that manages Intent resolution and Tool execution.
class AIEngine {
  final int companyId;
  final String locale;
  final Map<AIIntent, AIBusinessTool> _registry;

  AIEngine(this.companyId, {this.locale = 'ur'}) : _registry = {
    AIIntent.getSales: SalesTool(companyId, locale: locale),
    AIIntent.getLowStock: StockTool(companyId, locale: locale),
    AIIntent.getReceivables: ReceivablesTool(companyId, locale: locale),
    AIIntent.getExpenses: ExpensesTool(companyId, locale: locale),
    AIIntent.getProfit: ProfitTool(companyId, locale: locale),
    AIIntent.getPurchases: PurchasesTool(companyId, locale: locale),
    AIIntent.getSupplierCount: SupplierCountTool(companyId, locale: locale),
    AIIntent.getProductCount: ProductCountTool(companyId, locale: locale),
    AIIntent.createExpense: CreateExpenseTool(companyId, locale: locale),
  };

  bool get isUrdu => locale.startsWith('ur');

  Future<AIResponse> processQuery(String query) async {
    final intent = _resolveIntentOffline(query);
    
    if (intent == AIIntent.unknown) {
      return AIResponse(isUrdu 
        ? "Maaf kijiye, main ye samajh nahi saka. Aap sales, stock, udhaar ya kharchon ke baray mein pooch sakte hain."
        : "Sorry, I couldn't understand that. You can ask about sales, stock, receivables, or expenses.");
    }

    final tool = _registry[intent];
    if (tool == null) return AIResponse("System Error: Tool not found.");

    // RBAC Check
    if (tool.requiresOwner && !Session.isOwner) {
      return AIResponse(isUrdu
        ? "Maaf kijiye, aapko ye maloomat dekhne ki ijazat nahi hai."
        : "Sorry, you don't have permission to see this information.");
    }

    // Check if it's a write action that needs confirmation
    if (intent == AIIntent.createExpense) {
      final amount = _extractAmount(query);
      if (amount == null) {
        return AIResponse(isUrdu
          ? "Kharchay ka amount kya hai? (E.g. '500 ka kharcha dalo')"
          : "What is the expense amount? (E.g. 'Add expense of 500')");
      }
      return AIResponse(
        isUrdu 
          ? "Kya main Rs. ${amount.toStringAsFixed(0)} ka kharcha record kar loon?"
          : "Should I record an expense of Rs. ${amount.toStringAsFixed(0)}?",
        pendingIntent: intent,
        params: {'amount': amount, 'category': 'Operating Expenses'},
      );
    }

    final resultText = await tool.execute({});
    return AIResponse(resultText);
  }

  Future<String> executeConfirmedAction(AIIntent intent, Map<String, dynamic> params) async {
    final tool = _registry[intent];
    if (tool == null) return "Error: Tool not found.";
    return await tool.execute(params);
  }

  double? _extractAmount(String query) {
    // Simple regex to find numbers in the string
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(query);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
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
    if (_matches(q, ['add expense', 'record kharcha', 'expense dalo'])) {
      return AIIntent.createExpense;
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
