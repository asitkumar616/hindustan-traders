import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_flat_bottom_nav.dart';
import '../widgets/app_voice_bottom_nav.dart' show AppNavItem;
import 'admin_business_list_screen.dart';
import 'admin_customer_list_screen.dart';
import 'admin_owner_management_screen.dart';
import 'login_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                ),
                const Expanded(child: Text('Settings', style: AppTextStyles.heading)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile Settings',
                    onTap: () => _comingSoon(context, 'Profile Settings'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    onTap: () => _comingSoon(context, 'Change Password'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    label: 'Language',
                    onTap: () => _comingSoon(context, 'Language settings'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notification Settings',
                    onTap: () => _comingSoon(context, 'Notification Settings'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => _comingSoon(context, 'Help & Support'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Logout',
                color: AppColors.danger,
                onTap: () => _logout(context),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppFlatBottomNav(
        accentColor: AppColors.adminPrimary,
        items: [
          AppNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', onTap: () => Navigator.maybePop(context)),
          AppNavItem(icon: Icons.manage_accounts_outlined, label: 'Owners', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOwnerManagementScreen()))),
          AppNavItem(icon: Icons.store_mall_directory_outlined, label: 'Businesses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBusinessListScreen()))),
          AppNavItem(icon: Icons.groups_2_outlined, label: 'Customers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: false)))),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.color = AppColors.textPrimary});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color))),
            if (color == AppColors.textPrimary) const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
