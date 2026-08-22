import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_dashboard_service.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_flat_bottom_nav.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/app_voice_bottom_nav.dart' show AppNavItem;
import 'admin_business_list_screen.dart';
import 'admin_customer_list_screen.dart';
import 'admin_owner_management_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _loadError;
  AdminDashboardSummary _summary = const AdminDashboardSummary(
    totalOwners: 0,
    totalBusinesses: 0,
    totalCustomers: 0,
    activeCustomers: 0,
  );
  List<AdminOwnerRecord> _pendingOwners = const <AdminOwnerRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final summary = await AdminDashboardService.fetchSummary();
      final owners = await AdminDashboardService.listOwners();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _pendingOwners = owners.where((owner) => owner.approvalStatus.toLowerCase() == 'pending').take(5).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Admin Dashboard', style: AppTextStyles.heading),
                  IconButton(onPressed: _logout, icon: const Icon(Icons.logout), color: AppColors.textPrimary),
                ],
              ),
              if (!AdminDashboardService.backendReady || !appState.backendReady) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(message: appState.backendStatus),
              ],
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(message: 'Something went wrong. Unable to load the dashboard.', onRetry: _load),
              ],
              const SizedBox(height: AppSpacing.xl),
              _loading
                  ? const AppLoadingState()
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.35,
                      children: [
                        AppStatCard(
                          icon: Icons.manage_accounts_rounded,
                          value: _summary.totalOwners.toString(),
                          label: 'Total Owners',
                          bg: const Color(0xFFEFE9FF),
                          fg: const Color(0xFF7C6EF2),
                          onTap: () => _push(const AdminOwnerManagementScreen()),
                        ),
                        AppStatCard(
                          icon: Icons.store_mall_directory_rounded,
                          value: _summary.totalBusinesses.toString(),
                          label: 'Total Businesses',
                          bg: const Color(0xFFE1F7E8),
                          fg: const Color(0xFF2E7D32),
                          onTap: () => _push(const AdminBusinessListScreen()),
                        ),
                        AppStatCard(
                          icon: Icons.groups_2_rounded,
                          value: _summary.totalCustomers.toString(),
                          label: 'Total Customers',
                          bg: const Color(0xFFE1F0FF),
                          fg: const Color(0xFF3B82F6),
                          onTap: () => _push(const AdminCustomerListScreen(onlyActive: false)),
                        ),
                        AppStatCard(
                          icon: Icons.verified_user_rounded,
                          value: _summary.activeCustomers.toString(),
                          label: 'Active Customers',
                          bg: const Color(0xFFFFF1DC),
                          fg: const Color(0xFFC9820A),
                          onTap: () => _push(const AdminCustomerListScreen(onlyActive: true)),
                        ),
                      ],
                    ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(
                title: 'Pending Approvals',
                actionLabel: 'View All',
                onAction: () => _push(const AdminOwnerManagementScreen()),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const SizedBox.shrink()
              else if (_pendingOwners.isEmpty)
                const AppEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'All Caught Up',
                  message: 'No owners are waiting for approval right now.',
                )
              else
                ..._pendingOwners.map(
                  (owner) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _PendingOwnerCard(owner: owner, onTap: () => _push(const AdminOwnerManagementScreen())),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'More Tools'),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ToolTile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      onTap: () => _push(const AdminReportsScreen()),
                    ),
                    const Divider(height: 1),
                    _ToolTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => _push(const AdminSettingsScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppFlatBottomNav(
        accentColor: AppColors.adminPrimary,
        items: [
          const AppNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', active: true),
          AppNavItem(icon: Icons.manage_accounts_outlined, label: 'Owners', onTap: () => _push(const AdminOwnerManagementScreen())),
          AppNavItem(icon: Icons.store_mall_directory_outlined, label: 'Businesses', onTap: () => _push(const AdminBusinessListScreen())),
          AppNavItem(icon: Icons.groups_2_outlined, label: 'Customers', onTap: () => _push(const AdminCustomerListScreen(onlyActive: false))),
        ],
      ),
    );
  }
}


class _PendingOwnerCard extends StatelessWidget {
  const _PendingOwnerCard({required this.owner, required this.onTap});

  final AdminOwnerRecord owner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.adminPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.adminPrimary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.ownerName, style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text(owner.businessName, style: AppTextStyles.bodyMuted, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFFF1DC), borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: const Text('Pending', style: TextStyle(color: Color(0xFFC9820A), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: AppColors.adminPrimary, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
