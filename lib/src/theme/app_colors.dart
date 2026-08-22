import 'package:flutter/material.dart';

/// Semantic color palette layered on top of [AppTheme]'s ColorScheme.
/// Use these for meanings that don't map cleanly onto Material roles
/// (status badges, muted text, hairline borders) so screens don't each
/// invent their own greys/reds.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF176B43);
  static const Color primaryLight = Color(0xFF2E9E6B);
  static const Color accent = Color(0xFFC98A2C);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB98A1F);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  static const Color textPrimary = Color(0xFF1A1D1B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color surfaceMuted = Color(0xFFF4F6F5);

  // Owner app accent -- scoped to the Owner Dashboard redesign, which uses a
  // purple/indigo identity distinct from the Customer app's green. Not wired
  // into the global ThemeData/ColorScheme so other Owner screens are
  // unaffected until they're redesigned too.
  static const Color ownerPrimary = Color(0xFF6C5CE7);
  static const Color ownerPrimaryDark = Color(0xFF5B4BD6);
  static const Color ownerPrimaryLight = Color(0xFF8579F2);

  static const Color statCustomersBg = Color(0xFFEFE9FF);
  static const Color statCustomersFg = Color(0xFF7C6EF2);
  static const Color statOrdersBg = Color(0xFFE1F0FF);
  static const Color statOrdersFg = Color(0xFF3B82F6);
  static const Color statPendingBg = Color(0xFFFFF1DC);
  static const Color statPendingFg = Color(0xFFC9820A);
  static const Color statAmountBg = Color(0xFFFFE3EC);
  static const Color statAmountFg = Color(0xFFEF5DA8);

  // Admin app accent -- a neutral blue distinct from Owner's purple and
  // Customer's green, matching the icon-badge-only styling of the Admin
  // screens in the mockup (no single dominant hero-card color to sample).
  static const Color adminPrimary = Color(0xFF2563EB);
  static const Color adminPrimaryDark = Color(0xFF1D4ED8);
  static const Color adminPrimaryLight = Color(0xFF3B82F6);
}
