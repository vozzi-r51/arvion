import 'package:flutter/material.dart';

/// Defines the logic family a business category belongs to.
/// This determines which features and data models are enabled for the business.
enum TemplateFamily {
  /// Standard retail logic (already implemented in Arvion)
  retailStandard,
  /// Retail with variants like Size/Color (Phase 20)
  retailVariant,
  /// Retail with custom fields (e.g., Weight, Purity for Jewelry)
  retailCustomFields,
  /// Inventory with unique IDs/Serial Numbers (Electronics)
  serializedInventory,
  /// Pharmacy logic with Batch and Expiry tracking
  retailBatchExpiry,
  /// Restaurant/Cafe logic with Table Management and KOT (Phase 22)
  foodService,
  /// Booking based (Hotels, Travel) - date range based inventory
  bookingBased,
  /// Workshop logic (Auto) - parts + labor service
  workshopJob,
  /// Farm operations - cycle tracking (crop season, animal batch)
  farmOperations,
  /// Manufacturing logic - BOM + Production Orders (Phase 21)
  manufacturing,
  /// Project based logic (Construction) - multi-invoice costing
  projectBased,
  /// Service based logic (Salon, Consultants) - no stock, appointment tracking
  serviceJob,
  /// Real Estate logic - property listing + rental tracking
  propertyBased,
  /// Logistics/Transport - vehicle + trip tracking
  fleetBased,
  /// Education - enrollment, course, recurring fee billing
  enrollmentBased,
  /// Non-profit - donations, funds, donor tracking
  nonprofit
}

class BusinessCategory {
  final String id;              // e.g., 'clothing_fashion'
  final String label;           // e.g., 'Clothing / Garments / Fashion'
  final IconData icon;
  final TemplateFamily family;  // Logic group
  final List<String> subtypes;  // Specific business types

  const BusinessCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.family,
    required this.subtypes,
  });
}

const List<BusinessCategory> kBusinessCategories = [
  BusinessCategory(
    id: 'general_retail',
    label: 'General Retail',
    icon: Icons.storefront,
    family: TemplateFamily.retailStandard,
    subtypes: ['General Store', 'Convenience Store', 'Department Store', 'Supermarket', 'Mini Mart', 'Variety Store'],
  ),
  BusinessCategory(
    id: 'wholesale',
    label: 'Wholesale / Distribution',
    icon: Icons.local_shipping,
    family: TemplateFamily.retailStandard,
    subtypes: ['General Wholesale', 'FMCG Distribution', 'Importer / Distributor', 'B2B Trading', 'Cash & Carry'],
  ),
  BusinessCategory(
    id: 'grocery',
    label: 'Grocery / Kiryana',
    icon: Icons.shopping_basket,
    family: TemplateFamily.retailStandard,
    subtypes: ['Kiryana', 'Grocery', 'Supermarket', 'Fresh Food Store', 'Meat / Butcher', 'Fruit & Vegetable'],
  ),
  BusinessCategory(
    id: 'clothing',
    label: "Clothing / Garments / Fashion",
    icon: Icons.checkroom,
    family: TemplateFamily.retailVariant,
    subtypes: ["Men's Wear", "Women's Wear", "Kids Wear", "Garments", 'Boutique', 'Fashion Store', 'Textile', 'Uniforms', 'Tailoring'],
  ),
  BusinessCategory(
    id: 'footwear',
    label: 'Shoes / Footwear',
    icon: Icons.hiking,
    family: TemplateFamily.retailVariant,
    subtypes: ['Footwear Retail', 'Shoe Wholesale', 'Sports Footwear', 'Leather Footwear', 'Sandals / Slippers'],
  ),
  BusinessCategory(
    id: 'jewelry',
    label: 'Jewelry / Watches / Accessories',
    icon: Icons.diamond,
    family: TemplateFamily.retailCustomFields,
    subtypes: ['Jewelry', 'Gold / Silver', 'Artificial Jewelry', 'Watches', 'Fashion Accessories'],
  ),
  BusinessCategory(
    id: 'cosmetics',
    label: 'Cosmetics / Beauty',
    icon: Icons.face_retouching_natural,
    family: TemplateFamily.retailStandard,
    subtypes: ['Cosmetics', 'Perfumes / Fragrances', 'Beauty Products', 'Skincare', 'Haircare'],
  ),
  BusinessCategory(
    id: 'electronics',
    label: 'Electronics / Mobile / Technology',
    icon: Icons.devices,
    family: TemplateFamily.serializedInventory,
    subtypes: ['Mobile Shop', 'Mobile Accessories', 'Computer Store', 'Laptop / PC', 'Electronics', 'Home Appliances', 'CCTV / Security', 'Networking', 'Gaming'],
  ),
  BusinessCategory(
    id: 'hardware',
    label: 'Hardware / Sanitary / Building Materials',
    icon: Icons.hardware,
    family: TemplateFamily.retailStandard,
    subtypes: ['Hardware', 'Sanitary', 'Plumbing', 'Electrical', 'Paint Store', 'Building Materials', 'Tiles', 'Cement / Steel', 'Tools'],
  ),
  BusinessCategory(
    id: 'furniture',
    label: 'Furniture / Home & Living',
    icon: Icons.chair,
    family: TemplateFamily.retailStandard,
    subtypes: ['Furniture', 'Home Decor', 'Mattress / Bedding', 'Kitchenware', 'Crockery', 'Home Appliances', 'Lighting'],
  ),
  BusinessCategory(
    id: 'stationery',
    label: 'Stationery / Books / Education',
    icon: Icons.menu_book,
    family: TemplateFamily.retailStandard,
    subtypes: ['Stationery', 'Book Store', 'School Supplies', 'Office Supplies', 'Printing Supplies', 'Educational Materials'],
  ),
  BusinessCategory(
    id: 'pharmacy',
    label: 'Pharmacy / Medical / Healthcare',
    icon: Icons.local_pharmacy,
    family: TemplateFamily.retailBatchExpiry,
    subtypes: ['Pharmacy', 'Medical Store', 'Medical Equipment', 'Surgical Supplies', 'Dental Supplies', 'Optical Store', 'Veterinary Supplies'],
  ),
  BusinessCategory(
    id: 'restaurant',
    label: 'Restaurant / Cafe / Food',
    icon: Icons.restaurant,
    family: TemplateFamily.foodService,
    subtypes: ['Restaurant', 'Cafe', 'Fast Food', 'Bakery', 'Pizza / Burger', 'Catering', 'Cloud Kitchen', 'Food Truck', 'Juice / Beverage', 'Ice Cream / Dessert', 'Tandoor', 'Dhabah / Local Food'],
  ),
  BusinessCategory(
    id: 'hospitality',
    label: 'Hotel / Hospitality',
    icon: Icons.hotel,
    family: TemplateFamily.bookingBased,
    subtypes: ['Hotel', 'Guest House', 'Hostel', 'Resort', 'Event Venue', 'Banquet Hall'],
  ),
  BusinessCategory(
    id: 'automotive',
    label: 'Automotive',
    icon: Icons.directions_car,
    family: TemplateFamily.workshopJob,
    subtypes: ['Auto Parts', 'Car Workshop', 'Motorcycle Workshop', 'Car Dealer', 'Motorcycle Dealer', 'Tyre Shop', 'Battery Shop', 'Car Wash', 'Detailing', 'Lubricants / Oil', 'Auto Accessories'],
  ),
  BusinessCategory(
    id: 'agriculture',
    label: 'Agriculture / Farming',
    icon: Icons.agriculture,
    family: TemplateFamily.farmOperations,
    subtypes: ['Agriculture Supplies', 'Seeds', 'Fertilizer', 'Pesticides', 'Farm', 'Dairy Farm', 'Poultry', 'Livestock', 'Feed Store', 'Agricultural Machinery'],
  ),
  BusinessCategory(
    id: 'manufacturing',
    label: 'Manufacturing / Production',
    icon: Icons.precision_manufacturing,
    family: TemplateFamily.manufacturing,
    subtypes: ['Textile Manufacturing', 'Garment Manufacturing', 'Food Manufacturing', 'Furniture Manufacturing', 'Plastic Manufacturing', 'Metal Manufacturing', 'Chemical Manufacturing', 'Pharmaceutical Manufacturing', 'Packaging', 'General Manufacturing'],
  ),
  BusinessCategory(
    id: 'construction',
    label: 'Construction / Contracting',
    icon: Icons.construction,
    family: TemplateFamily.projectBased,
    subtypes: ['Construction Company', 'General Contractor', 'Electrical Contractor', 'Plumbing Contractor', 'Civil Works', 'Interior / Renovation', 'Architecture', 'Engineering'],
  ),
  BusinessCategory(
    id: 'services',
    label: 'Services',
    icon: Icons.miscellaneous_services,
    family: TemplateFamily.serviceJob,
    subtypes: ['Salon / Barber', 'Beauty Parlour', 'Workshop / Repair', 'Cleaning Services', 'Laundry', 'Dry Cleaning', 'Photography', 'Event Management', 'Security Services', 'Consulting', 'Freelancing', 'IT Services', 'Marketing Agency', 'Accounting Services', 'Legal Services', 'Design Agency'],
  ),
  BusinessCategory(
    id: 'professional',
    label: 'Professional Services',
    icon: Icons.badge,
    family: TemplateFamily.serviceJob,
    subtypes: ['Accountant', 'Lawyer', 'Consultant', 'Architect', 'Engineer', 'Doctor / Clinic', 'Dentist', 'Freelancer', 'Software Developer', 'Digital Agency'],
  ),
  BusinessCategory(
    id: 'real_estate',
    label: 'Real Estate / Property',
    icon: Icons.apartment,
    family: TemplateFamily.propertyBased,
    subtypes: ['Real Estate Agency', 'Property Dealer', 'Property Management', 'Construction & Development', 'Rental Business'],
  ),
  BusinessCategory(
    id: 'transport',
    label: 'Transport / Logistics',
    icon: Icons.local_shipping,
    family: TemplateFamily.fleetBased,
    subtypes: ['Transport Company', 'Courier', 'Delivery Service', 'Logistics', 'Freight Forwarding', 'Trucking', 'Rent-a-Car', 'Ride / Taxi Service'],
  ),
  BusinessCategory(
    id: 'travel',
    label: 'Travel / Tourism',
    icon: Icons.flight,
    family: TemplateFamily.bookingBased,
    subtypes: ['Travel Agency', 'Tour Operator', 'Ticketing Agency', 'Visa Services', 'Tourism'],
  ),
  BusinessCategory(
    id: 'education',
    label: 'Education / Training',
    icon: Icons.school,
    family: TemplateFamily.enrollmentBased,
    subtypes: ['School', 'Academy', 'Tuition Center', 'Training Institute', 'Vocational Center', 'Online Education'],
  ),
  BusinessCategory(
    id: 'printing',
    label: 'Printing / Publishing / Media',
    icon: Icons.print,
    family: TemplateFamily.retailStandard,
    subtypes: ['Printing Press', 'Digital Printing', 'Offset Printing', 'Publishing', 'Advertising', 'Signage', 'Media Agency'],
  ),
  BusinessCategory(
    id: 'sports',
    label: 'Sports / Fitness',
    icon: Icons.fitness_center,
    family: TemplateFamily.retailStandard,
    subtypes: ['Gym', 'Fitness Center', 'Sports Store', 'Sports Academy', 'Club', 'Personal Training'],
  ),
  BusinessCategory(
    id: 'pet',
    label: 'Pet / Animal',
    icon: Icons.pets,
    family: TemplateFamily.retailStandard,
    subtypes: ['Pet Store', 'Veterinary Clinic', 'Pet Grooming', 'Animal Feed', 'Livestock'],
  ),
  BusinessCategory(
    id: 'ecommerce',
    label: 'Online / E-commerce',
    icon: Icons.shopping_cart,
    family: TemplateFamily.retailStandard,
    subtypes: ['Online Store', 'Marketplace Seller', 'Dropshipping', 'Social Commerce', 'Subscription Business'],
  ),
  BusinessCategory(
    id: 'import_export',
    label: 'Import / Export / Trading',
    icon: Icons.public,
    family: TemplateFamily.retailStandard,
    subtypes: ['Importer', 'Exporter', 'Trading Company', 'International Trading', 'Sourcing Business'],
  ),
  BusinessCategory(
    id: 'nonprofit',
    label: 'Non-Profit / Organization',
    icon: Icons.volunteer_activism,
    family: TemplateFamily.nonprofit,
    subtypes: ['NGO', 'Charity', 'Association', 'Community Organization', 'Club / Society'],
  ),
  BusinessCategory(
    id: 'other',
    label: 'Other / Custom',
    icon: Icons.more_horiz,
    family: TemplateFamily.retailStandard,
    subtypes: [],
  ),
];
