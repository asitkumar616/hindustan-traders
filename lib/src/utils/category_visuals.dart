import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Maps a category name to an icon + accent color for image placeholders --
/// until product photo upload exists, this differentiates categories
/// visually instead of one flat basket icon for every product. Shared
/// between the catalog list and product detail screens so a given category
/// always renders the same way.
({IconData icon, Color color}) categoryVisual(String? category) {
  switch (category) {
    case 'Rice & Grains':
      return (icon: Icons.rice_bowl_rounded, color: AppColors.categoryRice);
    case 'Dal & Pulses':
      return (icon: Icons.grain_rounded, color: AppColors.categoryDal);
    case 'Oil':
      return (icon: Icons.water_drop_rounded, color: AppColors.categoryOil);
    case 'Spices':
      return (icon: Icons.local_fire_department_rounded, color: AppColors.categorySpice);
    case 'Flour':
      return (icon: Icons.bakery_dining_rounded, color: AppColors.categoryOil);
    case 'Vegetables':
      return (icon: Icons.eco_rounded, color: AppColors.success);
    case 'Beverages':
      return (icon: Icons.local_cafe_rounded, color: AppColors.categoryOther);
    case 'Household':
      return (icon: Icons.cleaning_services_rounded, color: AppColors.categoryOther);
    case 'Packaged Food':
      return (icon: Icons.inventory_2_rounded, color: AppColors.categorySpice);
    default:
      return (icon: Icons.shopping_basket_outlined, color: AppColors.navy);
  }
}
