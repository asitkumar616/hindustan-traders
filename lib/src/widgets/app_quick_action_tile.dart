import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

/// One tile in a quick-actions grid (icon + label), e.g. Owner Dashboard's
/// Order / Customer / Product / Payment shortcuts.
class AppQuickActionTile extends StatelessWidget {
  const AppQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: AppTextStyles.subheading),
        ],
      ),
    );
  }
}
