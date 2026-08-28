import 'package:shared_preferences/shared_preferences.dart';

enum FeatureEntitlement {
  productsUnlimited,
  multiCompany,
  advancedManufacturing,
  fullExport,
  customBranding,
  fbrInvoicing,
}

enum SubscriptionPlan {
  free,
  pro,
  enterprise;

  String get displayName {
    switch (this) {
      case SubscriptionPlan.free:
        return 'BizManager Free';
      case SubscriptionPlan.pro:
        return 'BizManager Pro';
      case SubscriptionPlan.enterprise:
        return 'BizManager Enterprise';
    }
  }
}

/// Monetization & Subscription Entitlement Architecture.
/// Manages plan features and limits without prematurely blocking offline users or deleting data.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String _prefPlanKey = 'company_plan_tier';

  /// Returns current subscription plan for a company (default: Pro for offline users).
  Future<SubscriptionPlan> getCurrentPlan(int companyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('${_prefPlanKey}_$companyId');
      if (saved == 'free') return SubscriptionPlan.free;
      if (saved == 'enterprise') return SubscriptionPlan.enterprise;
      return SubscriptionPlan
          .pro; // Default to Pro so offline users enjoy full access
    } catch (_) {
      return SubscriptionPlan.pro;
    }
  }

  /// Evaluates feature entitlement for a company.
  /// Always returns true for Pro / Enterprise plans and defaults safely without hard blocks.
  Future<bool> hasEntitlement(FeatureEntitlement feature, int companyId) async {
    final plan = await getCurrentPlan(companyId);
    if (plan == SubscriptionPlan.pro || plan == SubscriptionPlan.enterprise) {
      return true;
    }

    switch (feature) {
      case FeatureEntitlement.fullExport:
      case FeatureEntitlement.fbrInvoicing:
        return true; // Keep data export and compliance free for trust
      case FeatureEntitlement.productsUnlimited:
      case FeatureEntitlement.multiCompany:
      case FeatureEntitlement.advancedManufacturing:
      case FeatureEntitlement.customBranding:
        return false;
    }
  }

  /// Returns maximum products allowed for plan (null = unlimited).
  Future<int?> getMaxProductsAllowed(int companyId) async {
    final plan = await getCurrentPlan(companyId);
    if (plan == SubscriptionPlan.free) return 100;
    return null; // Unlimited for Pro / Enterprise
  }

  /// Sets or updates subscription plan tier for a company.
  Future<void> setPlan(int companyId, SubscriptionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefPlanKey}_$companyId', plan.name);
  }
}
