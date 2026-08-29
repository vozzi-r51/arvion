import 'package:flutter/material.dart';
import '../business_types/business_type_catalog.dart';

/// Single Chart-of-Accounts row used for per-category seeding.
class CoaSeed {
  final String code;
  final String name;
  final String type; // asset | liability | equity | income | expense
  const CoaSeed(this.code, this.name, this.type);

  Map<String, String> toMap() => {'code': code, 'name': name, 'type': type};
}

class BusinessTemplate {
  final String id;
  final String title;
  final IconData icon;
  final TemplateFamily family;
  final List<CoaSeed> defaultCoa;
  final List<String> defaultCategories;
  final List<String> defaultUnits;
  final List<String> enabledModules;
  final Map<String, String> terminology;
  final bool hasVariants;
  final bool hasBatchExpiry;
  final bool hasSerialNumbers;
  final bool hasCustomFields;

  const BusinessTemplate({
    required this.id,
    required this.title,
    required this.icon,
    required this.family,
    required this.defaultCoa,
    required this.defaultCategories,
    required this.defaultUnits,
    required this.enabledModules,
    required this.terminology,
    this.hasVariants = false,
    this.hasBatchExpiry = false,
    this.hasSerialNumbers = false,
    this.hasCustomFields = false,
  });
}

/// Reusable per-category COA definitions. The 5 user-requested categories
/// (Retail, Trading, Manufacturing, Services, Restaurant) each get their
/// own seeded chart of accounts so journal entries have the right accounts
/// from day one.
class _CategoryCoa {
  // Base retail accounts — Cash, Bank, AR, Inventory, Liabilities, Equity
  static const List<CoaSeed> retailBase = [
    CoaSeed('1001', 'Cash', 'asset'),
    CoaSeed('1002', 'Bank', 'asset'),
    CoaSeed('1003', 'Accounts Receivable', 'asset'),
    CoaSeed('1004', 'Inventory', 'asset'),
    CoaSeed('1005', 'Fixed Assets', 'asset'),
    CoaSeed('2001', 'Accounts Payable', 'liability'),
    CoaSeed('2002', 'Loans', 'liability'),
    CoaSeed('2003', 'Salaries Payable', 'liability'),
    CoaSeed('2004', 'Sales Tax Payable', 'liability'),
    CoaSeed('3001', "Owner's Capital", 'equity'),
    CoaSeed('3002', "Owner's Drawings", 'equity'),
    CoaSeed('3003', 'Retained Earnings', 'equity'),
    CoaSeed('4001', 'Sales Revenue', 'income'),
    CoaSeed('4002', 'Other Income', 'income'),
    CoaSeed('5001', 'Cost of Goods Sold', 'expense'),
    CoaSeed('5002', 'Operating Expenses', 'expense'),
    CoaSeed('5003', 'Rent', 'expense'),
    CoaSeed('5004', 'Electricity', 'expense'),
    CoaSeed('5005', 'Salaries', 'expense'),
    CoaSeed('5006', 'Taxes', 'expense'),
    CoaSeed('5009', 'Office Supplies', 'expense'),
  ];

  static List<CoaSeed> trading() {
    return [
      ...retailBase,
      const CoaSeed('4021', 'Purchase Discount', 'income'),
      const CoaSeed('4022', 'Sales Returns', 'income'),
      const CoaSeed('5007', 'Freight Inward', 'expense'),
      const CoaSeed('5010', 'Import Duty', 'expense'),
      const CoaSeed('5015', 'Clearing & Forwarding', 'expense'),
    ];
  }

  static List<CoaSeed> manufacturing() {
    return [
      ...retailBase,
      const CoaSeed('1006', 'Raw Materials Inventory', 'asset'),
      const CoaSeed('1007', 'Work in Progress', 'asset'),
      const CoaSeed('1008', 'Finished Goods Inventory', 'asset'),
      const CoaSeed('5008', 'Manufacturing Overhead', 'expense'),
      const CoaSeed('5011', 'Wages - Direct', 'expense'),
      const CoaSeed('5012', 'Factory Supplies', 'expense'),
    ];
  }

  static List<CoaSeed> service() {
    return [
      ...retailBase,
      const CoaSeed('4010', 'Service Revenue', 'income'),
      const CoaSeed('4011', 'Consulting Income', 'income'),
      const CoaSeed('5013', 'Travel & Conveyance', 'expense'),
      const CoaSeed('5014', 'Communication Expense', 'expense'),
    ];
  }

  static List<CoaSeed> restaurant() {
    return [
      ...retailBase,
      const CoaSeed('4030', 'Food Sales', 'income'),
      const CoaSeed('4031', 'Beverage Sales', 'income'),
      const CoaSeed('5020', 'Food Cost', 'expense'),
      const CoaSeed('5021', 'Beverage Cost', 'expense'),
      const CoaSeed('5022', 'Kitchen Supplies', 'expense'),
      const CoaSeed('2010', 'Waiter Tips Payable', 'liability'),
    ];
  }
}

class BusinessTemplates {
  BusinessTemplates._();

  static BusinessTemplate getByFamily(TemplateFamily family,
      {String? categoryTitle, IconData? icon}) {
    switch (family) {
      case TemplateFamily.retailStandard:
      case TemplateFamily.projectBased:
      case TemplateFamily.propertyBased:
      case TemplateFamily.fleetBased:
      case TemplateFamily.enrollmentBased:
      case TemplateFamily.nonprofit:
        return BusinessTemplate(
          id: 'retail_standard',
          title: categoryTitle ?? 'General Retail',
          icon: icon ?? Icons.storefront,
          family: family,
          defaultCoa: _CategoryCoa.retailBase,
          defaultCategories: ['Uncategorized'],
          defaultUnits: ['Piece', 'Pack', 'Box'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Product'
          },
        );
      case TemplateFamily.trading:
        return BusinessTemplate(
          id: 'trading',
          title: categoryTitle ?? 'Wholesale / Trading',
          icon: icon ?? Icons.local_shipping,
          family: family,
          defaultCoa: _CategoryCoa.trading(),
          defaultCategories: ['General Trading', 'Imports', 'Exports'],
          defaultUnits: ['Piece', 'Carton', 'Kg'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Item'
          },
        );
      case TemplateFamily.retailVariant:
        return BusinessTemplate(
          id: 'retail_variant',
          title: categoryTitle ?? 'Clothing / Footwear',
          icon: icon ?? Icons.checkroom,
          family: family,
          defaultCoa: _CategoryCoa.retailBase,
          defaultCategories: ['Men', 'Women', 'Kids'],
          defaultUnits: ['Piece', 'Suit', 'Pair'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting',
            'promotions'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Item'
          },
          hasVariants: true,
        );
      case TemplateFamily.retailCustomFields:
        return BusinessTemplate(
          id: 'retail_custom',
          title: categoryTitle ?? 'Jewelry',
          icon: icon ?? Icons.diamond,
          family: family,
          defaultCoa: _CategoryCoa.retailBase,
          defaultCategories: ['Gold', 'Silver', 'Diamond'],
          defaultUnits: ['Gram', 'Tola', 'Piece'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Jewelry'
          },
          hasCustomFields: true,
        );
      case TemplateFamily.serializedInventory:
        return BusinessTemplate(
          id: 'serialized',
          title: categoryTitle ?? 'Electronics / Mobile',
          icon: icon ?? Icons.devices,
          family: family,
          defaultCoa: _CategoryCoa.retailBase,
          defaultCategories: ['Mobiles', 'Accessories', 'Laptops'],
          defaultUnits: ['Unit', 'Set', 'Piece'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Device'
          },
          hasSerialNumbers: true,
        );
      case TemplateFamily.retailBatchExpiry:
        return BusinessTemplate(
          id: 'batch_expiry',
          title: categoryTitle ?? 'Pharmacy',
          icon: icon ?? Icons.local_pharmacy,
          family: family,
          defaultCoa: _CategoryCoa.retailBase,
          defaultCategories: ['Tablets', 'Syrups', 'Surgical'],
          defaultUnits: ['Strip', 'Bottle', 'Piece'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Medicine'
          },
          hasBatchExpiry: true,
        );
      case TemplateFamily.foodService:
        return BusinessTemplate(
          id: 'food_service',
          title: categoryTitle ?? 'Restaurant / Cafe',
          icon: icon ?? Icons.restaurant,
          family: family,
          defaultCoa: _CategoryCoa.restaurant(),
          defaultCategories: ['Starters', 'Main Course', 'Beverages'],
          defaultUnits: ['Plate', 'Serving', 'Glass'],
          enabledModules: ['sales', 'inventory', 'expenses', 'hr'],
          terminology: {
            'sale': 'Order',
            'invoice': 'Bill',
            'product': 'Menu Item'
          },
        );
      case TemplateFamily.bookingBased:
        return BusinessTemplate(
          id: 'booking_based',
          title: categoryTitle ?? 'Hospitality / Travel',
          icon: icon ?? Icons.hotel,
          family: family,
          defaultCoa: _CategoryCoa.service(),
          defaultCategories: ['Rooms', 'Packages', 'Services'],
          defaultUnits: ['Night', 'Person', 'Ticket'],
          enabledModules: ['sales', 'expenses', 'accounting'],
          terminology: {
            'sale': 'Booking',
            'invoice': 'Receipt',
            'product': 'Service'
          },
        );
      case TemplateFamily.workshopJob:
        return BusinessTemplate(
          id: 'workshop_job',
          title: categoryTitle ?? 'Automotive / Workshop',
          icon: icon ?? Icons.directions_car,
          family: family,
          defaultCoa: _CategoryCoa.service(),
          defaultCategories: ['Spare Parts', 'Lubricants', 'Services'],
          defaultUnits: ['Piece', 'Litre', 'Job'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting'
          ],
          terminology: {
            'sale': 'Job Card',
            'invoice': 'Invoice',
            'product': 'Part'
          },
        );
      case TemplateFamily.farmOperations:
        return BusinessTemplate(
          id: 'farm_operations',
          title: categoryTitle ?? 'Agriculture / Farm',
          icon: icon ?? Icons.agriculture,
          family: family,
          defaultCoa: _CategoryCoa.retailBase,
          defaultCategories: ['Seeds', 'Fertilizers', 'Crops'],
          defaultUnits: ['Kg', 'Bag', 'Mound'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses'],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Item'
          },
        );
      case TemplateFamily.manufacturing:
        return BusinessTemplate(
          id: 'manufacturing',
          title: categoryTitle ?? 'Manufacturing',
          icon: icon ?? Icons.precision_manufacturing,
          family: family,
          defaultCoa: _CategoryCoa.manufacturing(),
          defaultCategories: ['Raw Materials', 'Finished Goods'],
          defaultUnits: ['Kg', 'Unit', 'Batch'],
          enabledModules: [
            'sales',
            'purchases',
            'inventory',
            'expenses',
            'accounting',
            'hr'
          ],
          terminology: {
            'sale': 'Sale',
            'invoice': 'Invoice',
            'product': 'Finished Good'
          },
        );
      case TemplateFamily.serviceJob:
        return BusinessTemplate(
          id: 'service_job',
          title: categoryTitle ?? 'Services',
          icon: icon ?? Icons.miscellaneous_services,
          family: family,
          defaultCoa: _CategoryCoa.service(),
          defaultCategories: ['Consulting', 'Repair', 'Other Services'],
          defaultUnits: ['Hour', 'Visit', 'Job'],
          enabledModules: ['sales', 'expenses', 'accounting'],
          terminology: {
            'sale': 'Service',
            'invoice': 'Invoice',
            'product': 'Service'
          },
        );
    }
  }

  static BusinessTemplate getById(String id) {
    final cat = kBusinessCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => kBusinessCategories.first,
    );
    return getByFamily(cat.family, categoryTitle: cat.label, icon: cat.icon);
  }
}
