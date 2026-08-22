import '../theme/app_theme.dart';

/// Semantic aliases for [AppTheme]'s corner radii, so widgets can reference
/// `AppRadius.md` instead of reaching into the theme class directly.
class AppRadius {
  AppRadius._();

  static const double sm = AppTheme.radiusSmall;
  static const double md = AppTheme.radiusMedium;
  static const double lg = AppTheme.radiusLarge;
  static const double pill = 999;
}
