import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'app_voice_bottom_nav.dart' show AppNavItem;

/// Flat bottom bar shared by the Owner and Customer dashboards -- no center
/// voice button (unlike [AppVoiceBottomNav], used by the rest of each app).
/// Voice/Ask Assistant stays reachable from other screens (Orders/Products
/// for Owner, the More menu for Customer), so nothing is lost -- these two
/// dashboards just don't show it, matching their approved mockups. The
/// active tab gets a light brand-tint pill behind its icon.
class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({super.key, required this.items});

  final List<AppNavItem> items;

  @override
  Widget build(BuildContext context) {
    // Android phones with on-screen nav buttons or a gesture bar paint their
    // own system UI in this exact strip. Without this inset, that system UI
    // sits on top of our nav icons and swallows every tap aimed at them.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 64 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: items.map((item) => Expanded(child: _DashboardNavIcon(item: item))).toList(),
      ),
    );
  }
}

class _DashboardNavIcon extends StatelessWidget {
  const _DashboardNavIcon({required this.item});

  final AppNavItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.active ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: item.active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(item.icon, size: 21, color: color),
          ),
          const SizedBox(height: 2),
          Text(item.label, style: TextStyle(fontSize: 10, color: color, fontWeight: item.active ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
