import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_voice_bottom_nav.dart' show AppNavItem;

/// Plain flat bottom nav bar (no center voice button) for the Admin app,
/// which has no voice feature. Shares [AppNavItem] with [AppVoiceBottomNav]
/// so the same item list shape works across both nav styles.
class AppFlatBottomNav extends StatelessWidget {
  const AppFlatBottomNav({super.key, required this.items, this.accentColor = AppColors.primary});

  final List<AppNavItem> items;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: items.map((item) => Expanded(child: _FlatNavIcon(item: item, accent: accentColor))).toList(),
      ),
    );
  }
}

class _FlatNavIcon extends StatelessWidget {
  const _FlatNavIcon({required this.item, required this.accent});

  final AppNavItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = item.active ? accent : AppColors.textSecondary;
    return InkWell(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(item.label, style: TextStyle(fontSize: 10, color: color, fontWeight: item.active ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
