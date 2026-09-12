import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/models/product_variant.dart';
import '../src/services/cart_state.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/category_visuals.dart';
import '../src/utils/formatters.dart';
import '../src/utils/product_images.dart';
import '../src/widgets/app_quantity_stepper.dart';
import '../src/widgets/app_section_header.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _wishlisted = false;
  late List<ProductVariant> _variants;
  ProductVariant? _selected;

  @override
  void initState() {
    super.initState();
    _variants = (widget.product['variants'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProductVariant.fromMap)
        .toList();
    _selected = _variants.isNotEmpty ? _variants.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    final productId = widget.product['id']?.toString() ?? '';
    final name = widget.product['name']?.toString() ?? 'Product';
    final brand = widget.product['brand']?.toString();
    final variant = _selected;
    final quantity = variant != null && cart.quantityFor(variant.id) > 0 ? cart.quantityFor(variant.id) : 1.0;
    final total = (variant?.sellingPrice ?? 0) * quantity;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _wishlisted = !_wishlisted),
                    icon: Icon(
                      _wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _wishlisted ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (context) {
                      final category = widget.product['category']?.toString();
                      final visual = categoryVisual(category);
                      final imageAsset = productImageAsset(productName: name, category: category);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.asset(
                          imageAsset,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: double.infinity,
                            height: 220,
                            color: visual.color.withValues(alpha: 0.08),
                            child: Icon(visual.icon, color: visual.color, size: 72),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.xl),
                    Text(name, style: AppTextStyles.heading),
                    if (brand != null && brand.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(brand, style: AppTextStyles.bodyMuted),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      variant == null ? 'Not available' : '₹${formatIndianAmount(variant.sellingPrice)} / ${variant.label}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_variants.isEmpty)
                      const Text('This product has no pack sizes available right now.', style: AppTextStyles.bodyMuted)
                    else ...[
                      const AppSectionHeader(title: 'Select Pack Size'),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _variants.map((v) {
                          final isSelected = v.id == variant?.id;
                          return _VariantChip(
                            variant: v,
                            selected: isSelected,
                            onTap: () => setState(() => _selected = v),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const AppSectionHeader(title: 'Select Quantity'),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: AppQuantityStepper(
                          quantity: quantity,
                          unit: variant!.packageType == 'LOOSE' ? variant.unit : variant.packageType,
                          min: variant.minimumOrderQuantity,
                          onChanged: (next) => cart.setQuantity(
                            productId: productId,
                            variantId: variant.id,
                            productName: name,
                            brand: brand,
                            variantQuantity: variant.quantity,
                            variantUnit: variant.unit,
                            packageType: variant.packageType,
                            price: variant.sellingPrice,
                            quantity: next,
                            minimumOrderQuantity: variant.minimumOrderQuantity,
                          ),
                        ),
                      ),
                      if (variant.minimumOrderQuantity > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Minimum order: ${variant.minimumOrderQuantity.toStringAsFixed(0)}', style: AppTextStyles.caption),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total', style: AppTextStyles.bodyMuted),
                      Text(
                        '₹${formatIndianAmount(total)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: (productId.isEmpty || variant == null)
                        ? null
                        : () {
                            cart.setQuantity(
                              productId: productId,
                              variantId: variant.id,
                              productName: name,
                              brand: brand,
                              variantQuantity: variant.quantity,
                              variantUnit: variant.unit,
                              packageType: variant.packageType,
                              price: variant.sellingPrice,
                              quantity: quantity,
                              minimumOrderQuantity: variant.minimumOrderQuantity,
                            );
                            Navigator.maybePop(context);
                          },
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('Add to Cart'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.variant, required this.selected, required this.onTap});

  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: selected ? AppColors.navy : AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              variant.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              '₹${formatIndianAmount(variant.sellingPrice)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: selected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
