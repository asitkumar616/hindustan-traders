class MasterProduct {
  final String id;
  final String productName;
  final String? productNameOdia;
  final String category;
  final String? brand;
  final String? imageUrl;
  final String baseUnit;
  final bool isActive;

  const MasterProduct({
    required this.id,
    required this.productName,
    this.productNameOdia,
    required this.category,
    this.brand,
    this.imageUrl,
    required this.baseUnit,
    this.isActive = true,
  });

  factory MasterProduct.fromMap(Map<String, dynamic> map) {
    return MasterProduct(
      id: map['id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      productNameOdia: map['product_name_odia']?.toString(),
      category: map['category']?.toString() ?? 'Others',
      brand: map['brand']?.toString(),
      imageUrl: map['image_url']?.toString(),
      baseUnit: map['base_unit']?.toString() ?? 'KG',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// Fixed catalog categories shown as filter chips -- matches the spec's
/// enumerated list. "Others" is always the catch-all for custom products.
const List<String> kMasterProductCategories = [
  'Rice & Grains',
  'Dal & Pulses',
  'Flour',
  'Oil',
  'Spices',
  'Vegetables',
  'Packaged Food',
  'Beverages',
  'Household',
  'Others',
];

const List<String> kVariantUnits = ['KG', 'GRAM', 'LTR', 'ML', 'PCS', 'BAG', 'PACK', 'BOX', 'CARTON'];

const List<String> kVariantPackageTypes = ['LOOSE', 'PACK', 'BAG', 'BOX', 'CARTON'];
