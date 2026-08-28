import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Privacy-Aware User Feedback & Feature Suggestion Service.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const String _prefPendingFeedbackKey = 'pending_user_feedback_list';

  /// Saves user feature suggestion locally for transmission when online.
  /// Strictly excludes passwords, PINs, database encryption keys, and private business ledgers.
  Future<String> submitFeedback({
    required int companyId,
    required String title,
    required String category,
    required String description,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const FormatException('Feature title is required.');
    }

    final feedbackItem = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'company_id': companyId,
      'title': cleanTitle,
      'category': category,
      'description': description.trim(),
      'submitted_at': DateTime.now().toIso8601String(),
      'status': 'pending_sync',
    };

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefPendingFeedbackKey) ?? [];
    rawList.add(jsonEncode(feedbackItem));
    await prefs.setStringList(_prefPendingFeedbackKey, rawList);

    return 'submitted_locally';
  }

  /// Retrieves list of locally saved pending feedback items.
  Future<List<Map<String, dynamic>>> getPendingFeedbackList() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefPendingFeedbackKey) ?? [];
    return rawList.map((str) => jsonDecode(str) as Map<String, dynamic>).toList();
  }
}
