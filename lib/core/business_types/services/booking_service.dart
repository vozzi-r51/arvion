import '../../database/db_helper.dart';

/// Hotel & Travel Resource Booking Engine.
/// Prevents overlapping reservations for rooms/seats.
class BookingService {
  BookingService._();

  /// Create a bookable resource (Hotel Room / Travel Seat / Hall).
  static Future<int> createResource({
    required int companyId,
    required String name,
    String type = 'room',
    int capacity = 1,
    required double unitPrice,
  }) async {
    final db = await DBHelper.instance.database;
    return await db.insert('bookable_resources', {
      'company_id': companyId,
      'name': name,
      'type': type,
      'capacity': capacity,
      'unit_price': unitPrice,
      'status': 'available',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Creates a booking after verifying date range availability.
  /// Throws StateError if an overlapping active booking exists.
  static Future<int> createBooking({
    required int companyId,
    int? customerId,
    required int resourceId,
    required String bookingNumber,
    required String startDate, // "2026-09-01"
    required String endDate,   // "2026-09-04"
    required double totalAmount,
  }) async {
    final db = await DBHelper.instance.database;

    // Check overlapping bookings: start1 < end2 AND start2 > end1
    final overlaps = await db.query(
      'bookings',
      where: 'company_id = ? AND resource_id = ? AND status != "cancelled" AND start_date < ? AND end_date > ?',
      whereArgs: [companyId, resourceId, endDate, startDate],
    );

    if (overlaps.isNotEmpty) {
      throw StateError('Resource is already booked for the selected dates ($startDate to $endDate).');
    }

    return await db.insert('bookings', {
      'company_id': companyId,
      'customer_id': customerId,
      'resource_id': resourceId,
      'booking_number': bookingNumber,
      'start_date': startDate,
      'end_date': endDate,
      'status': 'confirmed',
      'total_amount': totalAmount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
