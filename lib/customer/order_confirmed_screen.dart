import 'package:flutter/material.dart';
import '../src/models/order_payment.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_primary_button.dart';
import '../src/widgets/app_secondary_button.dart';
import 'customer_orders_screen.dart';

/// Confirmation shown once an order has a payment method attached.
/// Cash on Delivery orders land here with a "payment pending" note (the
/// owner confirms cash receipt later); a paid UPI order would show the
/// paid variant once a real gateway exists -- see paymentStatus.
class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentStatus = OrderPaymentStatus.pending,
  });

  final String orderId;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;

  String get _shortOrderNumber {
    final compact = orderId.replaceAll('-', '');
    return (compact.length >= 6 ? compact.substring(0, 6) : compact).toUpperCase();
  }

  String get _paymentMethodLabel => paymentMethod == OrderPaymentMethod.upi ? 'UPI' : 'Cash on Delivery';

  bool get _isPaid => paymentStatus == OrderPaymentStatus.paid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_isPaid ? 'Payment Successful' : 'Order Confirmed', style: AppTextStyles.heading.copyWith(fontSize: 24)),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Text('Order #$_shortOrderNumber', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 4),
                    Text(
                      '₹${formatIndianAmount(totalAmount)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const Divider(height: AppSpacing.xl),
                    _InfoRow(label: 'Payment Method', value: _paymentMethodLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Payment Status',
                      value: _isPaid ? 'PAID' : 'PAYMENT PENDING',
                      valueColor: _isPaid ? AppColors.success : AppColors.warning,
                    ),
                  ],
                ),
              ),
              if (!_isPaid && paymentMethod == OrderPaymentMethod.cashOnDelivery) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Please pay the owner when the order is delivered.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted,
                ),
              ],
              const Spacer(),
              AppPrimaryButton(
                label: 'View Order',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
                  (route) => route.isFirst,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: 'Back to Home',
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMuted),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textPrimary),
        ),
      ],
    );
  }
}
