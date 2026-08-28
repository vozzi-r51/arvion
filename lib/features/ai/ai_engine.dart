import '../../core/database/db_helper.dart';
import '../../core/auth/session.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/tflite_intent_classifier.dart';
import '../../core/di/service_locator.dart';
import '../../core/repositories/sales_repository.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/purchase_repository.dart';
import '../../core/repositories/supplier_repository.dart';
import '../../core/repositories/expense_repository.dart';
import '../../core/repositories/analytics_repository.dart';

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
    final company = await DBHelper.instance.getCompanyById(companyId);
    final total = await sl<SalesRepository>().getTodaysSalesTotal(companyId);

    final formatted = CurrencyFormatter.format(
      total,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    return isUrdu
        ? "Aaj ki total sales $formatted hain."
        : "Today's total sales are $formatted.";
  }
}

class StockTool extends AIBusinessTool {
  StockTool(super.companyId, {super.locale});
  @override
  bool get requiresOwner => false;

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await sl<InventoryRepository>().getLowStockCount(companyId);
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
    final company = await DBHelper.instance.getCompanyById(companyId);
    final receivables = await DBHelper.instance.getReceivables(companyId);
    if (receivables.isEmpty) {
      return isUrdu
          ? "Mashallah, kisi customer se koi udhaar nahi lena."
          : "No receivables. All clear!";
    }
    final top = receivables.first;
    final total =
        receivables.fold(0.0, (sum, r) => sum + (r['current_balance'] as num));

    final totalFormatted = CurrencyFormatter.format(
      total,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    final topFormatted = CurrencyFormatter.format(
      top['current_balance'] as num,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    return isUrdu
        ? "Total receivables $totalFormatted hain. Sabse zyada udhaar ${top['name']} ka hai ($topFormatted)."
        : "Total receivables are $totalFormatted. Highest is from ${top['name']} ($topFormatted).";
  }
}

class ExpensesTool extends AIBusinessTool {
  ExpensesTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final company = await DBHelper.instance.getCompanyById(companyId);
    final total =
        await sl<ExpenseRepository>().getTodaysExpensesTotal(companyId);

    final formatted = CurrencyFormatter.format(
      total,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    return isUrdu
        ? "Aaj ke total kharchay $formatted hain."
        : "Today's total expenses are $formatted.";
  }
}

class ProfitTool extends AIBusinessTool {
  ProfitTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final company = await DBHelper.instance.getCompanyById(companyId);
    final total = await sl<AnalyticsRepository>().getTodaysProfit(companyId);

    final formatted = CurrencyFormatter.format(
      total,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    return isUrdu
        ? "Aaj ka estimated munafa $formatted hai."
        : "Today's estimated profit is $formatted.";
  }
}

class PurchasesTool extends AIBusinessTool {
  PurchasesTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final company = await DBHelper.instance.getCompanyById(companyId);
    final total =
        await sl<PurchaseRepository>().getTodaysPurchaseTotal(companyId);

    final formatted = CurrencyFormatter.format(
      total,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    return isUrdu
        ? "Aaj ki total purchase $formatted hai."
        : "Today's total purchase is $formatted.";
  }
}

class SupplierCountTool extends AIBusinessTool {
  SupplierCountTool(super.companyId, {super.locale});
  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final count = await sl<SupplierRepository>().getSupplierCount(companyId);
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
    final count = await sl<InventoryRepository>().getProductCount(companyId);
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

    final company = await DBHelper.instance.getCompanyById(companyId);
    await DBHelper.instance.insertExpense({
      'company_id': companyId,
      'category': category,
      'amount': amount,
      'expense_date': DateTime.now().toIso8601String(),
      'payment_method': 'Cash',
      'description': 'AI generated expense',
      'created_at': DateTime.now().toIso8601String(),
    });

    final formatted = CurrencyFormatter.format(
      amount,
      currencyCode: company?['currency_code'] as String? ?? 'PKR',
      symbol: company?['currency_symbol'] as String? ?? 'Rs.',
      decimalPlaces: company?['decimal_places'] as int? ?? 2,
    );

    return isUrdu
        ? "Theek hai, $formatted ka $category kharcha record kar liya gaya hai."
        : "Okay, recorded an expense of $formatted for $category.";
  }
}

/// The Orchestrator that manages Intent resolution and Tool execution.
class AIEngine {
  final int companyId;
  final String locale;
  final Map<AIIntent, AIBusinessTool> _registry;
  bool _tfliteReady = false;

  AIEngine(this.companyId, {this.locale = 'ur'})
      : _registry = {
          AIIntent.getSales: SalesTool(companyId, locale: locale),
          AIIntent.getLowStock: StockTool(companyId, locale: locale),
          AIIntent.getReceivables: ReceivablesTool(companyId, locale: locale),
          AIIntent.getExpenses: ExpensesTool(companyId, locale: locale),
          AIIntent.getProfit: ProfitTool(companyId, locale: locale),
          AIIntent.getPurchases: PurchasesTool(companyId, locale: locale),
          AIIntent.getSupplierCount:
              SupplierCountTool(companyId, locale: locale),
          AIIntent.getProductCount: ProductCountTool(companyId, locale: locale),
          AIIntent.createExpense: CreateExpenseTool(companyId, locale: locale),
        };

  bool get isUrdu => locale.startsWith('ur');

  /// Initialize TFLite model (call once on app startup)
  Future<void> initializeTFLite() async {
    _tfliteReady = await TFLiteIntentClassifier.initialize();
  }

  Future<AIResponse> processQuery(String query) async {
    final intent = await _resolveIntentOffline(query);

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

  Future<String> executeConfirmedAction(
      AIIntent intent, Map<String, dynamic> params) async {
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

  /// Resolve intent using TFLite classifier with keyword matching fallback
  Future<AIIntent> _resolveIntentOffline(String query) async {
    // Try TFLite classifier first (if available)
    if (_tfliteReady) {
      try {
        final (intent, confidence) =
            await TFLiteIntentClassifier.classifyQuery(query);
        if (intent != AIIntentType.unknown) {
          // Convert AIIntentType to AIIntent
          return _aiIntentTypeToIntent(intent);
        }
        // If TFLite returned unknown, fall through to keyword matching
      } catch (e) {
        print('⚠️  TFLite classification failed: $e, falling back to keywords');
      }
    }

    // Fallback: keyword matching (original logic)
    final q = query.toLowerCase();

    if (_matches(q, [
      'today',
      'aj',
      'aaj',
      'sales',
      'sale',
      'فروخت',
      'سیلز',
      'آج',
      'bikri',
      'revenue',
      'figure'
    ])) {
      return AIIntent.getSales;
    }
    if (_matches(q, [
      'low stock',
      'stock kam',
      'inventory kam',
      'out of stock',
      'سٹاک',
      'انوینٹری',
      'low item',
      'shortage',
      'reorder',
      'alert'
    ])) {
      return AIIntent.getLowStock;
    }
    if (_matches(q, [
      'owe',
      'receivable',
      'udhaar',
      'paisa lena',
      'customer balance',
      'ادھار',
      'وصولی',
      'outstanding',
      'due',
      'debt'
    ])) {
      return AIIntent.getReceivables;
    }
    if (_matches(q, [
      'expense',
      'kharcha',
      'kharchay',
      'اخراجات',
      'خرچہ',
      'operating',
      'kharcha'
    ])) {
      return AIIntent.getExpenses;
    }
    if (_matches(q, [
      'profit',
      'munafa',
      'kamai',
      'منافع',
      'کمائی',
      'earnings',
      'net',
      'gross'
    ])) {
      return AIIntent.getProfit;
    }
    if (_matches(q, [
      'purchase',
      'kharidari',
      'maal kharida',
      'خریداری',
      'buying',
      'maal',
      'inventory'
    ])) {
      return AIIntent.getPurchases;
    }
    if (_matches(q, ['supplier', 'vendor', 'سپلائر', 'vendors'])) {
      return AIIntent.getSupplierCount;
    }
    if (_matches(q, [
      'total product',
      'kitne product',
      'total items',
      'آئٹم',
      'items',
      'product list'
    ])) {
      return AIIntent.getProductCount;
    }
    if (_matches(q,
        ['add expense', 'record kharcha', 'expense dalo', 'record', 'entry'])) {
      return AIIntent.createExpense;
    }

    return AIIntent.unknown;
  }

  /// Convert AIIntentType (from TFLite) to AIIntent (app enum)
  AIIntent _aiIntentTypeToIntent(AIIntentType type) {
    switch (type) {
      case AIIntentType.getSales:
        return AIIntent.getSales;
      case AIIntentType.getLowStock:
        return AIIntent.getLowStock;
      case AIIntentType.getReceivables:
        return AIIntent.getReceivables;
      case AIIntentType.getExpenses:
        return AIIntent.getExpenses;
      case AIIntentType.getProfit:
        return AIIntent.getProfit;
      case AIIntentType.getPurchases:
        return AIIntent.getPurchases;
      case AIIntentType.getSupplierCount:
        return AIIntent.getSupplierCount;
      case AIIntentType.getProductCount:
        return AIIntent.getProductCount;
      case AIIntentType.createExpense:
        return AIIntent.createExpense;
      default:
        return AIIntent.unknown;
    }
  }

  bool _matches(String query, List<String> keywords) {
    for (var k in keywords) {
      if (query.contains(k)) return true;
    }
    return false;
  }
}
