import 'package:flutter/material.dart';
import 'business_type_catalog.dart';

class BusinessTemplate {
  final String id;
  final String title;
  final IconData icon;
  final TemplateFamily family;
  final List<String> defaultCoa;
  final List<String> defaultCategories;
  final List<String> defaultUnits;
  final List<String> enabledModules;
  final Map<String, String> terminology;

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
  });
}

class BusinessTemplates {
  BusinessTemplates._();

  static BusinessTemplate getByFamily(TemplateFamily family, {String? categoryTitle, IconData? icon}) {
    switch (family) {
      case TemplateFamily.retailStandard:
        return BusinessTemplate(
          id: 'retail_standard',
          title: categoryTitle ?? 'General Retail',
          icon: icon ?? Icons.storefront,
          family: family,
          defaultCoa: ['Sales', 'Cost of Goods Sold', 'Inventory Asset', 'Cash', 'Operating Expenses'],
          defaultCategories: ['Uncategorized'],
          defaultUnits: ['Piece', 'Pack', 'Box'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses', 'accounting'],
          terminology: {'sale': 'Sale', 'invoice': 'Invoice', 'product': 'Product'},
        );
      case TemplateFamily.retailVariant:
        return BusinessTemplate(
          id: 'retail_variant',
          title: categoryTitle ?? 'Clothing / Footwear',
          icon: icon ?? Icons.checkroom,
          family: family,
          defaultCoa: ['Garment Sales', 'Cost of Goods Sold', 'Inventory Asset', 'Cash', 'Operating Expenses'],
          defaultCategories: ['Men', 'Women', 'Kids'],
          defaultUnits: ['Piece', 'Suit', 'Pair'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses', 'accounting', 'promotions'],
          terminology: {'sale': 'Sale', 'invoice': 'Invoice', 'product': 'Item'},
        );
      case TemplateFamily.retailCustomFields:
        return BusinessTemplate(
          id: 'retail_custom',
          title: categoryTitle ?? 'Jewelry',
          icon: icon ?? Icons.diamond,
          family: family,
          defaultCoa: ['Jewelry Sales', 'Gold Purchases', 'Inventory Asset', 'Cash', 'Operating Expenses'],
          defaultCategories: ['Gold', 'Silver', 'Diamond'],
          defaultUnits: ['Gram', 'Tola', 'Piece'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses', 'accounting'],
          terminology: {'sale': 'Sale', 'invoice': 'Invoice', 'product': 'Jewelry'},
        );
      case TemplateFamily.serializedInventory:
        return BusinessTemplate(
          id: 'serialized',
          title: categoryTitle ?? 'Electronics / Mobile',
          icon: icon ?? Icons.devices,
          family: family,
          defaultCoa: ['Device Sales', 'Service Income', 'Cost of Goods Sold', 'Cash', 'Operating Expenses'],
          defaultCategories: ['Mobiles', 'Accessories', 'Laptops'],
          defaultUnits: ['Unit', 'Set', 'Piece'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses', 'accounting'],
          terminology: {'sale': 'Sale', 'invoice': 'Invoice', 'product': 'Device'},
        );
      case TemplateFamily.retailBatchExpiry:
        return BusinessTemplate(
          id: 'batch_expiry',
          title: categoryTitle ?? 'Pharmacy',
          icon: icon ?? Icons.local_pharmacy,
          family: family,
          defaultCoa: ['Medicine Sales', 'COGS - Medicine', 'Inventory Asset', 'Cash', 'Operating Expenses'],
          defaultCategories: ['Tablets', 'Syrups', 'Surgical'],
          defaultUnits: ['Strip', 'Bottle', 'Piece'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses', 'accounting'],
          terminology: {'sale': 'Sale', 'invoice': 'Invoice', 'product': 'Medicine'},
        );
      case TemplateFamily.foodService:
        return BusinessTemplate(
          id: 'food_service',
          title: categoryTitle ?? 'Restaurant / Cafe',
          icon: icon ?? Icons.restaurant,
          family: family,
          defaultCoa: ['Food Sales', 'Beverage Sales', 'Food Cost', 'Kitchen Supplies', 'Cash', 'Waiter Tips'],
          defaultCategories: ['Starters', 'Main Course', 'Beverages'],
          defaultUnits: ['Plate', 'Serving', 'Glass'],
          enabledModules: ['sales', 'inventory', 'expenses', 'hr'],
          terminology: {'sale': 'Order', 'invoice': 'Bill', 'product': 'Menu Item'},
        );
      case TemplateFamily.manufacturing:
        return BusinessTemplate(
          id: 'manufacturing',
          title: categoryTitle ?? 'Manufacturing',
          icon: icon ?? Icons.precision_manufacturing,
          family: family,
          defaultCoa: ['Finished Goods Sales', 'Raw Material Asset', 'WIP Inventory', 'Manufacturing Overhead', 'Factory Wages'],
          defaultCategories: ['Raw Materials', 'Finished Goods'],
          defaultUnits: ['Kg', 'Unit', 'Batch'],
          enabledModules: ['sales', 'purchases', 'inventory', 'expenses', 'accounting', 'hr'],
          terminology: {'sale': 'Sale', 'invoice': 'Invoice', 'product': 'Finished Good'},
        );
      default:
        // Fallback for others to retailStandard
        return getByFamily(TemplateFamily.retailStandard, categoryTitle: categoryTitle, icon: icon);
    }
  }

  static BusinessTemplate getById(String id) {
    final cat = kBusinessCategories.firstWhere((c) => c.id == id, orElse: () => kBusinessCategories.first);
    return getByFamily(cat.family, categoryTitle: cat.label, icon: cat.icon);
  }
}
