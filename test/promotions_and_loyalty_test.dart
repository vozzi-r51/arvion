import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/promotions/promotion_engine.dart';
import 'package:bizmanager/core/loyalty/loyalty_service.dart';

void main() {
  group('Promotion Engine - Rule Calculations & Eligibility Tests', () {
    test(
        'Buy 2 Get 1 Free promotion calculates correct free quantity and discount',
        () {
      final promotion = {
        'id': 101,
        'name': 'Buy 2 Get 1 Free',
        'type': 'buy_x_get_y',
        'value': 0.0,
        'min_quantity': 2,
        'free_quantity': 1,
        'active': 1,
      };

      final saleItems = [
        {'product_id': 1, 'quantity': 3, 'price': 100.0},
      ];

      final result = PromotionEngine.evaluate(
        promotion: promotion,
        saleItems: saleItems,
        subtotal: 300.0,
      );

      expect(result.isEligible, isTrue);
      expect(result.freeQuantity, equals(1));
      expect(result.discountAmount, equals(100.0));
    });

    test('Coupon code evaluation matches case-insensitively and trimmed', () {
      final promotion = {
        'id': 102,
        'name': 'Eid Discount',
        'type': 'percent',
        'value': 20.0,
        'coupon_code': 'EID20',
        'active': 1,
      };

      final saleItems = [
        {'product_id': 1, 'quantity': 1, 'price': 1000.0},
      ];

      final result1 = PromotionEngine.evaluate(
        promotion: promotion,
        saleItems: saleItems,
        subtotal: 1000.0,
        enteredCouponCode: '  eid20  ',
      );

      expect(result1.isEligible, isTrue);
      expect(result1.discountAmount, equals(200.0));

      final result2 = PromotionEngine.evaluate(
        promotion: promotion,
        saleItems: saleItems,
        subtotal: 1000.0,
        enteredCouponCode: 'WRONGCODE',
      );

      expect(result2.isEligible, isFalse);
      expect(result2.reason, contains('coupon'));
    });

    test(
        'Total usage limit rejects promotion when current_use_count >= max_uses_total',
        () {
      final promotion = {
        'id': 103,
        'name': 'Limited Promo',
        'type': 'flat',
        'value': 100.0,
        'max_uses_total': 2,
        'current_use_count': 2,
        'active': 1,
      };

      final result = PromotionEngine.evaluate(
        promotion: promotion,
        saleItems: [],
        subtotal: 500.0,
      );

      expect(result.isEligible, isFalse);
      expect(result.reason, contains('usage limit reached'));
    });
  });

  group('Customer Loyalty Points Service Tests', () {
    test('Calculates loyalty points earned based on rate (1 point per 100 PKR)',
        () {
      final points = LoyaltyService.calculatePointsEarned(
        eligibleAmount: 1000.0,
        pointsPerCurrency: 0.01,
      );
      expect(points, equals(10.0));
    });

    test('Calculates redemption discount value (100 points = 100 PKR)', () {
      final discount = LoyaltyService.calculateRedemptionDiscount(
        pointsToRedeem: 100.0,
        redemptionRate: 1.0,
      );
      expect(discount, equals(100.0));
    });
  });
}
