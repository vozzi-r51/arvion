import '../business_types/business_type_catalog.dart';

/// Generates contextual messaging for business type setup
class TemplateMessaging {
  TemplateMessaging._();

  /// Get a business-specific highlight message about what was auto-enabled
  static String getSetupHighlight(TemplateFamily family) {
    switch (family) {
      case TemplateFamily.retailStandard:
        return 'Aapke business ke liye basic retail setup ready hai — Sales, Purchase aur Inventory sab ready hain.';

      case TemplateFamily.retailVariant:
        return 'Size, Color, aur dusre Variants already ready hain aapke products ke liye!';

      case TemplateFamily.retailCustomFields:
        return 'Weight, Purity, Hallmark fields already set hain — jewelry business ke liye perfect!';

      case TemplateFamily.serializedInventory:
        return 'Serial number tracking ready hai — har device ka track rakhna ab asaan ho gaya.';

      case TemplateFamily.retailBatchExpiry:
        return 'Batch aur Expiry date tracking automatically enable ho gaya — pharmacy ke liye zaroori!';

      case TemplateFamily.foodService:
        return 'Table Management aur Kitchen Orders already ON kar diye hain — restaurant khul gaya!';

      case TemplateFamily.bookingBased:
        return 'Booking calendar aur date-range inventory ready hai — hospitality business ke liye perfect!';

      case TemplateFamily.workshopJob:
        return 'Parts inventory aur Labor service billing both enabled — workshop ready ho gaya!';

      case TemplateFamily.farmOperations:
        return 'Crop cycle tracking aur farm inventory setup ready hai — kheti ke liye tailored!';

      case TemplateFamily.manufacturing:
        return 'Bill of Materials aur Production Orders enabled — manufacturing start kar sakte ho!';

      case TemplateFamily.projectBased:
        return 'Project costing aur multi-invoice tracking ready — construction projects ke liye!';

      case TemplateFamily.serviceJob:
        return 'Service-based billing setup ho gaya — consultant ya salon business ke liye ready!';

      case TemplateFamily.propertyBased:
        return 'Property listing aur rental tracking enabled — real estate business ready hai!';

      case TemplateFamily.fleetBased:
        return 'Vehicle aur trip tracking setup ho gaya — logistics business ke liye perfect!';

      case TemplateFamily.enrollmentBased:
        return 'Enrollment management aur recurring fee billing enabled — education business ready!';

      case TemplateFamily.nonprofit:
        return 'Donor tracking aur fund management setup ho gaya — nonprofit operations ready hain!';
      case TemplateFamily.trading:
        return 'Wholesale aur distribution setup ready — freight, duties, aur supplier returns sab enabled hain!';
    }
  }

  /// Get a shorter tagline for quick reference
  static String getBusinessTagline(TemplateFamily family) {
    switch (family) {
      case TemplateFamily.retailStandard:
        return 'Basic Retail Setup';
      case TemplateFamily.retailVariant:
        return 'Variants Management';
      case TemplateFamily.retailCustomFields:
        return 'Custom Fields Ready';
      case TemplateFamily.serializedInventory:
        return 'Serial Tracking';
      case TemplateFamily.retailBatchExpiry:
        return 'Batch & Expiry';
      case TemplateFamily.foodService:
        return 'Restaurant Ready';
      case TemplateFamily.bookingBased:
        return 'Booking System';
      case TemplateFamily.workshopJob:
        return 'Parts & Labor';
      case TemplateFamily.farmOperations:
        return 'Farm Operations';
      case TemplateFamily.manufacturing:
        return 'Manufacturing Ready';
      case TemplateFamily.projectBased:
        return 'Project Costing';
      case TemplateFamily.serviceJob:
        return 'Service Billing';
      case TemplateFamily.propertyBased:
        return 'Property Rentals';
      case TemplateFamily.fleetBased:
        return 'Fleet Management';
      case TemplateFamily.enrollmentBased:
        return 'Enrollment System';
      case TemplateFamily.nonprofit:
        return 'Nonprofit Setup';
      case TemplateFamily.trading:
        return 'Wholesale & Trading';
    }
  }

  /// Get key features enabled for this template family
  static List<String> getEnabledFeatures(TemplateFamily family) {
    const baseFeatures = ['Sales', 'Purchases', 'Inventory'];

    switch (family) {
      case TemplateFamily.retailStandard:
      case TemplateFamily.projectBased:
      case TemplateFamily.propertyBased:
      case TemplateFamily.fleetBased:
      case TemplateFamily.enrollmentBased:
      case TemplateFamily.nonprofit:
        return [...baseFeatures, 'Accounting', 'Expenses'];

      case TemplateFamily.retailVariant:
        return [...baseFeatures, 'Variants', 'Promotions', 'Accounting'];

      case TemplateFamily.retailCustomFields:
        return [...baseFeatures, 'Custom Fields', 'Accounting'];

      case TemplateFamily.serializedInventory:
        return [...baseFeatures, 'Serial Numbers', 'Accounting'];

      case TemplateFamily.retailBatchExpiry:
        return [
          ...baseFeatures,
          'Batch Tracking',
          'Expiry Dates',
          'Accounting'
        ];

      case TemplateFamily.foodService:
        return ['Sales', 'Tables', 'Kitchen Orders', 'Inventory', 'HR'];

      case TemplateFamily.bookingBased:
        return ['Bookings', 'Calendar', 'Services', 'Accounting'];

      case TemplateFamily.workshopJob:
        return [...baseFeatures, 'Labor Billing', 'Job Tracking'];

      case TemplateFamily.farmOperations:
        return [...baseFeatures, 'Cycle Tracking', 'Batch Management'];

      case TemplateFamily.manufacturing:
        return [...baseFeatures, 'BOM', 'Production Orders', 'Accounting'];

      case TemplateFamily.serviceJob:
        return ['Services', 'Appointments', 'Billing', 'Accounting'];

      case TemplateFamily.trading:
        return [
          ...baseFeatures,
          'Wholesale Pricing',
          'Freight & Duties',
          'Supplier Returns',
          'Accounting'
        ];
    }
  }

  /// Get emoji icon for feature display
  static String getFeatureEmoji(String feature) {
    switch (feature.toLowerCase()) {
      case 'sales':
        return '💰';
      case 'purchases':
        return '📦';
      case 'inventory':
        return '📊';
      case 'accounting':
        return '📋';
      case 'expenses':
        return '💸';
      case 'variants':
        return '🎨';
      case 'promotions':
        return '🎁';
      case 'custom fields':
        return '⚙️';
      case 'serial numbers':
        return '🔢';
      case 'batch tracking':
        return '📌';
      case 'expiry dates':
        return '📅';
      case 'tables':
        return '🪑';
      case 'kitchen orders':
        return '👨‍🍳';
      case 'hr':
        return '👥';
      case 'bookings':
        return '📆';
      case 'calendar':
        return '📅';
      case 'services':
        return '🛠️';
      case 'labor billing':
        return '🔧';
      case 'job tracking':
        return '📋';
      case 'cycle tracking':
        return '🔄';
      case 'batch management':
        return '📦';
      case 'bom':
        return '⚙️';
      case 'production orders':
        return '🏭';
      case 'appointments':
        return '📞';
      case 'billing':
        return '💳';
      default:
        return '✓';
    }
  }
}
