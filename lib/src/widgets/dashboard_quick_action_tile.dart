import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Compact quick-action tile shared by the Owner and Customer dashboards --
/// smaller icon/label than the older [AppQuickActionTile] (still used
/// elsewhere, e.g. the Owner product screen's voice entry point), sized so
/// 4 tiles fit one row without the label text wrapping.
class DashboardQuickActionTile extends StatelessWidget {
  const DashboardQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
