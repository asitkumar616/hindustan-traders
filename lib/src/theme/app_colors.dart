import 'package:flutter/material.dart';

/// Semantic color palette layered on top of [AppTheme]'s ColorScheme.
/// Use these for meanings that don't map cleanly onto Material roles
/// (status badges, muted text, hairline borders) so screens don't each
/// invent their own greys/reds.
class AppColors {
  AppColors._();

  // OdiaTraders brand palette -- matches the logo mark exactly (#FF8A00
  // orange, #2457C5 blue). Orange drives every primary call-to-action button
  // (Continue, Add to Cart, Place Order, Save...); "navy" (the blue) is the
  // structural color (headings, selected states, icon badges), used
  // consistently across Customer/Owner/Admin -- unlike the earlier
  // role-differentiated green/purple/blue scheme, this uses ONE identity
  // everywhere.
  static const Color primary = Color(0xFFFF8A00);
  static const Color primaryLight = Color(0xFFFFAB4D);
  static const Color primaryDark = Color(0xFFCC6E00);

  static const Color navy = Color(0xFF2457C5);
  static const Color navyLight = Color(0xFF4A78D6);
  static const Color navyDark = Color(0xFF1B4499);

  static const Color accent = Color(0xFF17325C);

  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFB98A1F);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFF1A1D1B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color surfaceMuted = Color(0xFFFFFFFF);

  // Category icon accents -- the mockup's category grid/badges use a mixed
  // palette (not one dominant color), so these are shared across whichever
  // screens render category chips/icons.
  static const Color categoryRice = primary;
  static const Color categoryDal = Color(0xFF7C6EF2);
  static const Color categoryOil = Color(0xFFE0A72E);
  static const Color categorySpice = Color(0xFFC62828);
  static const Color categoryOther = Color(0xFF3B82F6);

  // Kept as aliases so existing Owner/Admin screens immediately pick up the
  // unified navy identity instead of their old purple/blue without needing
  // every call site rewritten in this pass.
  static const Color ownerPrimary = navy;
  static const Color ownerPrimaryDark = navyDark;
  static const Color ownerPrimaryLight = navyLight;

  static const Color statCustomersBg = Color(0xFFEFE9FF);
  static const Color statCustomersFg = Color(0xFF7C6EF2);
  static const Color statOrdersBg = Color(0xFFE1F0FF);
  static const Color statOrdersFg = Color(0xFF3B82F6);
  static const Color statPendingBg = Color(0xFFFFF1DC);
  static const Color statPendingFg = Color(0xFFC9820A);
  static const Color statAmountBg = Color(0xFFFFE3EC);
  static const Color statAmountFg = Color(0xFFEF5DA8);

  static const Color adminPrimary = navy;
  static const Color adminPrimaryDark = navyDark;
  static const Color adminPrimaryLight = navyLight;
}
