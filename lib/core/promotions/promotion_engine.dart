/// Evaluation result from Promotion Engine.
class PromotionEvaluationResult {
  final bool isEligible;
  final int? promotionId;
  final String? promotionName;
  final double discountAmount;
  final int freeQuantity;
  final String reason;

  const PromotionEvaluationResult({
    required this.isEligible,
    this.promotionId,
    this.promotionName,
    this.discountAmount = 0.0,
    this.freeQuantity = 0,
    this.reason = '',
  });

  static const ineligible = PromotionEvaluationResult(
    isEligible: false,
    reason: 'Promotion unavailable or ineligible',
  );
}

/// Central Promotion Rule Engine.
class PromotionEngine {
  PromotionEngine._();

  /// Evaluates promotion eligibility and calculates exact discount/free items.
  static PromotionEvaluationResult evaluate({
    required Map<String, dynamic> promotion,
    required List<Map<String, dynamic>> saleItems,
    required double subtotal,
    int? customerId,
    int customerUsageCount = 0,
    String? enteredCouponCode,
  }) {
    final active = (promotion['active'] as num?)?.toInt() ?? 1;
    if (active != 1) {
      return const PromotionEvaluationResult(isEligible: false, reason: 'Promotion is inactive');
    }

    // Date validity
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final rawStart = (promotion['start_date'] as String? ?? '');
    final rawEnd = (promotion['end_date'] as String? ?? '');
    final startDate = rawStart.length >= 10 ? rawStart.substring(0, 10) : '';
    final endDate = rawEnd.length >= 10 ? rawEnd.substring(0, 10) : '';

    if (startDate.isNotEmpty && todayStr.compareTo(startDate) < 0) {
      return const PromotionEvaluationResult(isEligible: false, reason: 'Promotion has not started yet');
    }
    if (endDate.isNotEmpty && todayStr.compareTo(endDate) > 0) {
      return const PromotionEvaluationResult(isEligible: false, reason: 'Promotion has expired');
    }

    // Coupon Code Match
    final requiredCoupon = (promotion['coupon_code'] as String? ?? '').trim().toLowerCase();
    if (requiredCoupon.isNotEmpty) {
      final userCoupon = (enteredCouponCode ?? '').trim().toLowerCase();
      if (userCoupon.isEmpty || userCoupon != requiredCoupon) {
        return const PromotionEvaluationResult(isEligible: false, reason: 'Invalid or missing coupon code');
      }
    }

    // Total Usage Limit
    final maxTotal = promotion['max_uses_total'] as int?;
    final currentCount = (promotion['current_use_count'] as num?)?.toInt() ?? 0;
    if (maxTotal != null && currentCount >= maxTotal) {
      return const PromotionEvaluationResult(isEligible: false, reason: 'Promotion maximum usage limit reached');
    }

    // Per-Customer Usage Limit
    final maxPerCustomer = promotion['max_uses_per_customer'] as int?;
    if (maxPerCustomer != null && customerUsageCount >= maxPerCustomer) {
      return const PromotionEvaluationResult(isEligible: false, reason: 'Customer usage limit reached for this promotion');
    }

    // Category Filtering
    final categoryId = promotion['applicable_category_id'] as int?;
    double qualifyingSubtotal = subtotal;
    int qualifyingQty = 0;
    double itemPrice = 0.0;

    if (categoryId != null) {
      qualifyingSubtotal = 0.0;
      for (final item in saleItems) {
        if (item['category_id'] == categoryId) {
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final price = (item['unit_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
          qualifyingSubtotal += qty * price;
          qualifyingQty += qty;
          itemPrice = price;
        }
      }
      if (qualifyingQty == 0) {
        return const PromotionEvaluationResult(isEligible: false, reason: 'No qualifying items for this category promotion');
      }
    } else {
      for (final item in saleItems) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final price = (item['unit_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
        qualifyingQty += qty;
        if (price > 0) itemPrice = price;
      }
    }

    // Quantity Requirement
    final minQty = (promotion['min_quantity'] as num?)?.toInt() ?? 0;
    if (minQty > 0 && qualifyingQty < minQty) {
      return PromotionEvaluationResult(
        isEligible: false,
        reason: 'Minimum quantity of $minQty required (current: $qualifyingQty)',
      );
    }

    // Discount & Free Quantity Calculation
    final type = (promotion['type'] as String? ?? 'percent').toLowerCase();
    final value = (promotion['value'] as num?)?.toDouble() ?? 0.0;
    final freeQtyPerGroup = (promotion['free_quantity'] as num?)?.toInt() ?? 0;

    double discountAmount = 0.0;
    int totalFreeQty = 0;

    if (type == 'percent') {
      discountAmount = (qualifyingSubtotal * value) / 100.0;
    } else if (type == 'flat') {
      discountAmount = value.clamp(0.0, qualifyingSubtotal);
    } else if (type == 'buy_x_get_y') {
      final requiredPaidQty = minQty > 0 ? minQty : 2;
      final freeQty = freeQtyPerGroup > 0 ? freeQtyPerGroup : 1;
      final groupSize = requiredPaidQty + freeQty;

      if (qualifyingQty >= groupSize) {
        final numGroups = qualifyingQty ~/ groupSize;
        totalFreeQty = numGroups * freeQty;
        discountAmount = totalFreeQty * itemPrice;
      } else if (minQty > 0 && qualifyingQty >= minQty) {
        totalFreeQty = freeQty;
        discountAmount = totalFreeQty * itemPrice;
      }
    }

    final promId = promotion['id'] as int?;
    final promName = promotion['name'] as String? ?? 'Promotion';

    return PromotionEvaluationResult(
      isEligible: true,
      promotionId: promId,
      promotionName: promName,
      discountAmount: discountAmount.clamp(0.0, subtotal),
      freeQuantity: totalFreeQty,
      reason: 'Promotion eligible',
    );
  }
}
