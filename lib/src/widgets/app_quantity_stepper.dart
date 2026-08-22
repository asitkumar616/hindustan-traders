import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// [ − ]  qty unit  [ + ] control shared by the product catalog and cart
/// screens, so the selected quantity/unit is always shown the same way.
class AppQuantityStepper extends StatelessWidget {
  const AppQuantityStepper({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
  });

  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;

  String get _quantityLabel => quantity == quantity.roundToDouble() ? quantity.toStringAsFixed(0) : quantity.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: quantity > min ? () => onChanged((quantity - step).clamp(min, double.infinity)) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$_quantityLabel $unit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: () => onChanged(quantity + step)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.textSecondary.withValues(alpha: 0.4) : AppColors.primary),
      ),
    );
  }
}
