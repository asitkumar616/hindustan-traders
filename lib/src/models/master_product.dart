class MasterProduct {
  final String id;
  final String productName;
  final String? productNameOdia;
  final String category;
  final String? categoryId;
  final String? subcategoryId;
  final String? brand;
  final String? imageUrl;
  final String baseUnit;
  final bool isActive;

  const MasterProduct({
    required this.id,
    required this.productName,
    this.productNameOdia,
    required this.category,
    this.categoryId,
    this.subcategoryId,
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
      categoryId: map['category_id']?.toString(),
      subcategoryId: map['subcategory_id']?.toString(),
      brand: map['brand']?.toString(),
      imageUrl: map['image_url']?.toString(),
      baseUnit: map['base_unit']?.toString() ?? 'KG',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// Selling/base units across every supported business category -- not just
/// grocery's KG/BAG. Existing abbreviations (LTR, PCS) are kept as-is so
/// already-saved variants keep matching; new units are additive.
const List<String> kVariantUnits = [
  'KG',
  'GRAM',
  'LTR',
  'ML',
  'PCS',
  'BAG',
  'PACK',
  'BOX',
  'CARTON',
  'BUNDLE',
  'FEET',
  'METER',
  'SQFT',
  'SQM',
  'TON',
  'SHEET',
  'ROLL',
  'PAIR',
  'DOZEN',
  'BOTTLE',
  'STRIP',
  'UNIT',
];

const List<String> kVariantPackageTypes = ['LOOSE', 'PACK', 'BAG', 'BOX', 'CARTON'];
