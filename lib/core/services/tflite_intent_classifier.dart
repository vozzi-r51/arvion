import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

/// Enum for AI intents (mirrors ai_engine.dart)
enum AIIntentType {
  getSales,
  getLowStock,
  getReceivables,
  getExpenses,
  getProfit,
  getPurchases,
  getSupplierCount,
  getProductCount,
  createExpense,
  unknown,
}

/// TFLite-powered intent classifier for natural language understanding
class TFLiteIntentClassifier {
  static tflite.Interpreter? _interpreter;
  static const double CONFIDENCE_THRESHOLD = 0.65;
  static const int MAX_QUERY_LENGTH = 20;
  static const int VOCAB_SIZE = 1000;
  static const int EMBEDDING_DIM = 64;

  // Intent mapping: index (from model output) → AIIntentType
  static const Map<int, AIIntentType> _intentMap = {
    0: AIIntentType.getSales,
    1: AIIntentType.getLowStock,
    2: AIIntentType.getReceivables,
    3: AIIntentType.getExpenses,
    4: AIIntentType.getProfit,
    5: AIIntentType.getPurchases,
    6: AIIntentType.getSupplierCount,
    7: AIIntentType.getProductCount,
    8: AIIntentType.createExpense,
  };

  // Simple vocabulary (would be loaded from tokenizer_config.json in production)
  static final Map<String, int> _vocabulary = {
    'aaj': 1,
    'ki': 2,
    'sales': 3,
    'kya': 4,
    'hain': 5,
    'today': 6,
    's': 7,
    'kitna': 8,
    'bika': 9,
    'batao': 10,
    'low': 11,
    'stock': 12,
    'hai': 13,
    'inventory': 14,
    'kam': 15,
    'out': 16,
    'of': 17,
    'udhaar': 18,
    'customer': 19,
    'balance': 20,
    'receivables': 21,
    'total': 22,
    'paisa': 23,
    'lena': 24,
    'kharcha': 25,
    'expenses': 27,
    'kharchay': 28,
    'munafa': 29,
    'profit': 30,
    'kamai': 31,
    'rahi': 32,
    'purchase': 33,
    'kharidari': 34,
    'hui': 35,
    'maal': 36,
    'kharida': 37,
    'suppliers': 38,
    'vendor': 39,
    'count': 40,
    'products': 41,
    'items': 42,
    'add': 43,
    'expense': 44,
    'record': 45,
    'dalo': 46,
    'entry': 47,
    'mujhe': 48,
    'is': 49,
    'mahine': 50,
    'ka': 51,
    'week': 52,
    'month': 53,
    'hafte': 54,
    'check': 55,
    'kro': 56,
    'problem': 57,
    'alert': 58,
    'needed': 59,
    'shortage': 60,
    'issue': 61,
    'owe': 62,
    'due': 63,
    'debt': 64,
    'outstanding': 65,
    'log': 66,
    'track': 67,
    'buying': 68,
    'status': 69,
    'how': 70,
    'many': 71,
    'list': 72,
    'figure': 73,
    'estimated': 74,
    'net': 75,
    'gross': 76,
    'margin': 77,
    'revenue': 78,
    'bikri': 79,
    'daily': 80,
    'operating': 81,
    'calculation': 82,
    'calculated': 83,
  };

  /// Initialize TFLite interpreter (call once on app startup)
  static Future<bool> initialize() async {
    try {
      _interpreter = await tflite.Interpreter.fromAsset(
        'assets/models/intent_classifier.tflite',
      );
      print('✅ TFLite model loaded successfully');
      return true;
    } catch (e) {
      print('❌ Failed to load TFLite model: $e');
      print('   Falling back to keyword matching');
      _interpreter = null;
      return false;
    }
  }

  /// Classify user query to intent with confidence score
  /// Returns (intent, confidence)
  /// If confidence < CONFIDENCE_THRESHOLD, intent will be unknown
  static Future<(AIIntentType intent, double confidence)> classifyQuery(
    String query,
  ) async {
    if (_interpreter == null) {
      return (AIIntentType.unknown, 0.0); // Trigger fallback in ai_engine
    }

    try {
      // Preprocess: tokenize and pad
      final tokenized = _tokenizeQuery(query);
      final input = _padSequence(tokenized, MAX_QUERY_LENGTH);

      // Prepare input: reshape to [1, MAX_QUERY_LENGTH]
      final inputTensor = input.reshape([1, MAX_QUERY_LENGTH]);

      // Prepare output buffer: 9 intent classes
      final output = List<double>.filled(9, 0.0).reshape([1, 9]);

      // Run inference
      _interpreter!.run(inputTensor, output);

      // Extract confidence scores from output
      final scores = output[0] as List<dynamic>;
      final scoresDouble = List<double>.from(scores);

      // Find highest score
      double maxScore = 0.0;
      int maxIndex = 0;
      for (int i = 0; i < scoresDouble.length; i++) {
        if (scoresDouble[i] > maxScore) {
          maxScore = scoresDouble[i];
          maxIndex = i;
        }
      }

      // Check confidence threshold
      if (maxScore < CONFIDENCE_THRESHOLD) {
        print(
            '⚠️  Low confidence (${(maxScore * 100).toStringAsFixed(1)}%) for intent $maxIndex');
        return (AIIntentType.unknown, maxScore);
      }

      final intent = _intentMap[maxIndex] ?? AIIntentType.unknown;
      print(
        '✅ Classified: "$query" → $intent (confidence: ${(maxScore * 100).toStringAsFixed(1)}%)',
      );
      return (intent, maxScore);
    } catch (e) {
      print('❌ Inference error: $e');
      return (AIIntentType.unknown, 0.0);
    }
  }

  /// Tokenize query: convert text to integer sequence using vocabulary
  static List<int> _tokenizeQuery(String query) {
    final normalized = query.toLowerCase();
    // Simple split by whitespace/punctuation
    final words = normalized.split(RegExp(r'[^\w؀-ۿ]+'));

    final tokens = <int>[];
    for (final word in words) {
      if (word.isEmpty) continue;

      // Look up word in vocabulary (or use OOV token if not found)
      final token = _vocabulary[word] ?? 0; // 0 = OOV (out of vocabulary)
      tokens.add(token);

      if (tokens.length >= MAX_QUERY_LENGTH) break;
    }

    return tokens;
  }

  /// Pad or truncate sequence to fixed length
  static List<int> _padSequence(List<int> sequence, int maxLen) {
    if (sequence.length >= maxLen) {
      return sequence.sublist(0, maxLen);
    }
    // Pad with zeros
    return [...sequence, ...List<int>.filled(maxLen - sequence.length, 0)];
  }

  /// Helper: reshape list for TFLite
  static List<List<int>> reshape(List<int> data, List<int> shape) {
    // Simplified reshape for 2D case
    if (shape.length == 2 && shape[0] == 1) {
      return [data];
    }
    return [data];
  }

  /// Gracefully dispose resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    print('🛑 TFLite interpreter disposed');
  }

  /// Get human-readable intent name
  static String getIntentName(AIIntentType intent) {
    switch (intent) {
      case AIIntentType.getSales:
        return 'Sales';
      case AIIntentType.getLowStock:
        return 'Low Stock';
      case AIIntentType.getReceivables:
        return 'Receivables';
      case AIIntentType.getExpenses:
        return 'Expenses';
      case AIIntentType.getProfit:
        return 'Profit';
      case AIIntentType.getPurchases:
        return 'Purchases';
      case AIIntentType.getSupplierCount:
        return 'Suppliers';
      case AIIntentType.getProductCount:
        return 'Products';
      case AIIntentType.createExpense:
        return 'Create Expense';
      case AIIntentType.unknown:
        return 'Unknown';
    }
  }
}

/// Extension for easy reshaping
extension Reshape<T> on List<T> {
  List<List<T>> reshape(List<int> shape) {
    if (shape.length == 2 && shape[0] == 1) {
      return [this];
    }
    throw UnsupportedError('Only 2D reshape with shape[0]=1 supported');
  }
}
