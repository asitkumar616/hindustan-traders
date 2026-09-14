import 'package:flutter/material.dart';
import '../src/models/order_payment.dart';
import '../src/services/payment_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_primary_button.dart';
import 'order_confirmed_screen.dart';

/// Shown right after an order is placed -- customer picks how they'll pay.
/// UPI is shown but disabled ("Coming soon") since no payment gateway is
/// wired up yet; only Cash on Delivery is a working path today. See
/// PaymentGatewayService for why UPI can't just be faked as working.
class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({
    super.key,
    required this.orderId,
    required this.businessName,
    required this.totalAmount,
  });

  final String orderId;
  final String businessName;
  final double totalAmount;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selected = OrderPaymentMethod.cashOnDelivery;
  bool _submitting = false;

  String get _shortOrderNumber {
    final compact = widget.orderId.replaceAll('-', '');
    return (compact.length >= 6 ? compact.substring(0, 6) : compact).toUpperCase();
  }

  Future<void> _continue() async {
    if (_selected != OrderPaymentMethod.cashOnDelivery) return;

    setState(() => _submitting = true);
    try {
      await PaymentService.setOrderPaymentMethod(
        orderId: widget.orderId,
        paymentMethod: OrderPaymentMethod.cashOnDelivery,
      );
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmedScreen(
            orderId: widget.orderId,
            totalAmount: widget.totalAmount,
            paymentMethod: OrderPaymentMethod.cashOnDelivery,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save payment method: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Payment'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #$_shortOrderNumber', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 2),
                    Text(widget.businessName, style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.xl),
                    const Text('Order Total', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 4),
                    Text(
                      '₹${formatIndianAmount(widget.totalAmount)}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text('Choose Payment Method', style: AppTextStyles.subheading),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentOptionTile(
                      icon: Icons.qr_code_rounded,
                      title: 'UPI',
                      subtitle: 'Pay securely using any UPI app',
                      selected: _selected == OrderPaymentMethod.upi,
                      enabled: false,
                      badge: 'Coming soon',
                      onTap: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentOptionTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Cash on Delivery',
                      subtitle: 'Pay when your order is delivered',
                      selected: _selected == OrderPaymentMethod.cashOnDelivery,
                      enabled: true,
                      onTap: () => setState(() => _selected = OrderPaymentMethod.cashOnDelivery),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: AppPrimaryButton(
                label: 'Continue',
                onPressed: _submitting ? null : _continue,
                loading: _submitting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final active = enabled && selected;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: active ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (active ? AppColors.primary : AppColors.navy).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: active ? AppColors.primary : AppColors.navy, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        if (badge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(AppRadius.pill)),
                            child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
