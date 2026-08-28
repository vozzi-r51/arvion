import 'package:intl/intl.dart';

/// Locale-aware date formatter that respects company date_format settings.
/// Supports: DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD
class DateFormatter {
  /// Parse and format a date string according to company settings.
  ///
  /// Parameters:
  ///   - dateStr: ISO 8601 date string (YYYY-MM-DD) or any standard format
  ///   - format: Company date format preference ('DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD')
  ///   - locale: BCP 47 language tag for month/day names (e.g., 'en', 'ur', 'ar')
  static String format(
    String dateStr, {
    required String format,
    String locale = 'en',
  }) {
    try {
      // Parse input (handle both ISO and various formats)
      DateTime date;

      // Try ISO format first (YYYY-MM-DD)
      if (dateStr.contains('-')) {
        date = DateTime.parse(dateStr);
      } else if (dateStr.contains('/')) {
        // Try DD/MM/YYYY or MM/DD/YYYY
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          // Assume ISO order by default
          date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          date = DateTime.now();
        }
      } else {
        date = DateTime.now();
      }

      return _formatDate(date, format);
    } catch (e) {
      return dateStr; // Fallback: return original string
    }
  }

  /// Format DateTime object according to format preference.
  static String formatDateTime(
    DateTime date, {
    required String format,
    String locale = 'en',
  }) {
    return _formatDate(date, format);
  }

  /// Get today's date in the specified format.
  static String today({required String format}) {
    return _formatDate(DateTime.now(), format);
  }

  /// Get a date range string (e.g., "Jan 1 - Jan 15, 2024").
  static String range(
    DateTime start,
    DateTime end, {
    required String format,
    String locale = 'en',
  }) {
    final startStr = _formatDate(start, format);
    final endStr = _formatDate(end, format);
    return '$startStr - $endStr';
  }

  /// Helper to format DateTime based on format string.
  static String _formatDate(DateTime date, String format) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    switch (format.toUpperCase()) {
      case 'DD/MM/YYYY':
        return '$day/$month/$year';
      case 'MM/DD/YYYY':
        return '$month/$day/$year';
      case 'YYYY-MM-DD':
        return '$year-$month-$day';
      case 'YYYY/MM/DD':
        return '$year/$month/$day';
      case 'DD-MM-YYYY':
        return '$day-$month-$year';
      default:
        return '$day/$month/$year'; // Default to DD/MM/YYYY
    }
  }

  /// Parse a formatted date string back to DateTime.
  /// Auto-detects format from separators and order.
  static DateTime parse(String dateStr) {
    try {
      // ISO format (YYYY-MM-DD)
      if (dateStr.startsWith(RegExp(r'\d{4}'))) {
        return DateTime.parse(dateStr);
      }

      // Extract parts
      final parts = dateStr.replaceAll(RegExp(r'[^\d]'), '/').split('/');
      if (parts.length != 3) return DateTime.now();

      final p0 = int.parse(parts[0]);
      final p1 = int.parse(parts[1]);
      final p2 = int.parse(parts[2]);

      // Detect format: if p0 > 12, it's DD; if p2 > 31, it's year
      int day, month, year;

      if (p2 > 31) {
        // YYYY-MM-DD or YYYY-DD-MM
        year = p0;
        if (p1 > 12) {
          // YYYY-DD-MM
          day = p1;
          month = p2;
        } else {
          // YYYY-MM-DD
          month = p1;
          day = p2;
        }
      } else if (p0 > 12) {
        // DD/MM/YYYY
        day = p0;
        month = p1;
        year = p2;
      } else {
        // MM/DD/YYYY (ambiguous, default to this)
        month = p0;
        day = p1;
        year = p2;
      }

      // Handle 2-digit years
      if (year < 100) {
        year += (year < 30) ? 2000 : 1900;
      }

      return DateTime(year, month, day);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Convert DateTime to ISO 8601 string (YYYY-MM-DD).
  static String toIso(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Check if a date is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Get the start of the month for a given date.
  static DateTime monthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get the end of the month for a given date.
  static DateTime monthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Get the start of the year for a given date.
  static DateTime yearStart(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  /// Get the end of the year for a given date.
  static DateTime yearEnd(DateTime date) {
    return DateTime(date.year + 1, 0, 0);
  }
}
