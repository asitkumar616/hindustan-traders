import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/services/cart_state.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    final id = widget.product['id']?.toString() ?? '';
    final name = widget.product['name']?.toString() ?? 'Product';
    final unit = widget.product['unit']?.toString() ?? 'unit';
    final price = (widget.product['price'] as num?)?.toDouble() ?? 0;
    final quantity = cart.quantityFor(id) > 0 ? cart.quantityFor(id) : 1.0;
    final total = price * quantity;

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
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(Icons.shopping_basket_outlined, color: AppColors.primary, size: 72),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(name, style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '₹${formatIndianAmount(price)} / $unit',
                      style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const AppSectionHeader(title: 'Select Unit'),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(
                        unit.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const AppSectionHeader(title: 'Select Quantity'),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: AppQuantityStepper(
                        quantity: quantity,
                        unit: unit,
                        onChanged: (next) =>
                            cart.setQuantity(productId: id, name: name, unit: unit, price: price, quantity: next),
                      ),
                    ),
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
                    onPressed: id.isEmpty
                        ? null
                        : () {
                            cart.setQuantity(productId: id, name: name, unit: unit, price: price, quantity: quantity);
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
