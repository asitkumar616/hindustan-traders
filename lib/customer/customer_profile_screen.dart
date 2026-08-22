import 'package:flutter/material.dart';
import '../src/models/user_profile.dart';
import '../src/screens/login_screen.dart';
import '../src/services/auth_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/widgets/app_card.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await AuthService.getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?.name?.isNotEmpty == true ? _profile!.name! : 'Customer';
    final phone = _profile?.phone ?? '';

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
                const Expanded(child: Text('Profile', style: AppTextStyles.heading)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTextStyles.subheading),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(phone, style: AppTextStyles.bodyMuted),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileTile(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () => _comingSoon('Edit Profile')),
                  const Divider(height: 1),
                  _ProfileTile(icon: Icons.language_rounded, label: 'Language', onTap: () => _comingSoon('Language settings')),
                  const Divider(height: 1),
                  _ProfileTile(icon: Icons.notifications_none_rounded, label: 'Notification Settings', onTap: () => _comingSoon('Notification Settings')),
                  const Divider(height: 1),
                  _ProfileTile(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => _comingSoon('Help & Support')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: _ProfileTile(icon: Icons.logout_rounded, label: 'Logout', color: AppColors.danger, onTap: _logout),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.label, required this.onTap, this.color = AppColors.textPrimary});

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
