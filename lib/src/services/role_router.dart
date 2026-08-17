import 'package:flutter/material.dart';
import '../screens/admin_dashboard_screen.dart';
import '../../customer/customer_shops_screen.dart';
import '../../owner/owner_home_screen.dart';
import '../models/user_profile.dart';
import '../screens/owner_onboarding_screen.dart';

class RoleRouter {
  static bool shouldShowOwnerOnboarding(UserProfile profile) {
    return profile.role == 'owner' && (profile.businessId == null || profile.businessId!.isEmpty);
  }

  static Widget routeForUser(UserProfile profile, {String? phone}) {
    if (profile.role == 'admin') {
      return const AdminDashboardScreen();
    }

    if (profile.role == 'owner') {
      if (shouldShowOwnerOnboarding(profile)) {
        return OwnerOnboardingScreen(phone: phone ?? profile.phone);
      }
      return const OwnerHomeScreen();
    }

    return const CustomerShopsScreen();
  }
}
