import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

/// Simple local (on-device) notifications — no server, no background
/// service. Checked once per app open (see maybeNotify) and rate-limited
/// to once per day so it doesn't spam the user every time they unlock.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> _show(int id, String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'dukanedge_alerts',
      'DukanEdge Alerts',
      channelDescription: 'Low stock and due payment reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Call once per app open (e.g. from MainShell). Shows at most one
  /// notification per day summarizing low stock and total receivables.
  static Future<void> maybeNotify(int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_notify_date';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString(key) == today) return;

    try {
      await init();
      final lowStockCount = await DBHelper.instance.getLowStockCount(companyId);
      final receivables = await DBHelper.instance.getReceivables(companyId);
      final totalReceivable =
          receivables.fold(0.0, (sum, c) => sum + (c['current_balance'] as num));

      if (lowStockCount > 0) {
        await _show(
          1001,
          'Low Stock Alert',
          '$lowStockCount product(s) ka stock kam hai — check karein.',
        );
      }
      if (totalReceivable > 0) {
        await _show(
          1002,
          'Due Payments',
          'Customers se total Rs. ${totalReceivable.toStringAsFixed(0)} lena baaki hai.',
        );
      }

      await prefs.setString(key, today);
    } catch (_) {
      // Notifications are a convenience — never block app startup on this.
    }
  }
}
