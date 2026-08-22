import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../src/services/cart_state.dart';
import '../src/services/order_draft_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_primary_button.dart';
import '../src/widgets/app_quantity_stepper.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _placingOrder = false;

  Future<void> _placeOrder(CartState cart) async {
    setState(() => _placingOrder = true);
    final result = await OrderDraftService.submitCart(businessId: cart.businessId, lines: cart.lines);
    if (!mounted) return;
    setState(() => _placingOrder = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      cart.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  const Expanded(
                    child: Text('Cart', style: AppTextStyles.heading, textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Ordering from', style: AppTextStyles.bodyMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cart.businessName,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: cart.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Your Cart is Empty',
                      message: 'Add products from the shop to see them here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
                      itemCount: cart.lines.length,
                      itemBuilder: (context, index) {
                        final line = cart.lines[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AppCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(line.name, style: AppTextStyles.subheading),
                                      const SizedBox(height: AppSpacing.sm),
                                      AppQuantityStepper(
                                        quantity: line.quantity,
                                        unit: line.unit,
                                        onChanged: (next) => cart.setQuantity(
                                          productId: line.productId,
                                          name: line.name,
                                          unit: line.unit,
                                          price: line.price,
                                          quantity: next,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${formatIndianAmount(line.amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (!cart.isEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: AppTextStyles.subheading),
                        Text(
                          '₹${formatIndianAmount(cart.subtotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(
                      label: 'Place Order',
                      onPressed: _placingOrder ? null : () => _placeOrder(cart),
                      loading: _placingOrder,
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
