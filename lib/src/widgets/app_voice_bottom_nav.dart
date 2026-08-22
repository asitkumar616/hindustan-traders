import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// One tappable slot in [AppVoiceBottomNav]'s outer row (icon + label).
class AppNavItem {
  const AppNavItem({required this.icon, required this.label, this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
}

/// The bottom navigation pattern shared by the Owner and Customer apps in
/// the reference mockups: a flat white bar with two nav items on either
/// side of a raised circular mic button docked in the center.
class AppVoiceBottomNav extends StatelessWidget {
  const AppVoiceBottomNav({
    super.key,
    required this.leftItems,
    required this.rightItems,
    required this.onVoice,
    this.accentDark = AppColors.primary,
    this.accentLight = AppColors.primary,
  });

  final List<AppNavItem> leftItems;
  final List<AppNavItem> rightItems;
  final VoidCallback onVoice;
  final Color accentDark;
  final Color accentLight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  ...leftItems.map((item) => Expanded(child: _NavIcon(item: item, accent: accentDark))),
                  const Expanded(child: SizedBox()),
                  ...rightItems.map((item) => Expanded(child: _NavIcon(item: item, accent: accentDark))),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onVoice,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accentDark, accentLight]),
                  boxShadow: [BoxShadow(color: accentDark.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.item, required this.accent});

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
