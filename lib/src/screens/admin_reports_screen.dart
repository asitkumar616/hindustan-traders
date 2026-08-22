import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_flat_bottom_nav.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_stat_card.dart';
import '../widgets/app_voice_bottom_nav.dart' show AppNavItem;
import 'admin_business_list_screen.dart';
import 'admin_customer_list_screen.dart';
import 'admin_owner_management_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _loading = true;
  String? _loadError;
  AdminDashboardSummary _summary = const AdminDashboardSummary(
    totalOwners: 0,
    totalBusinesses: 0,
    totalCustomers: 0,
    activeCustomers: 0,
  );

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
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
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
                  const Expanded(child: Text('Reports', style: AppTextStyles.heading)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  'Platform-wide totals across all businesses',
                  style: AppTextStyles.bodyMuted,
                ),
              ),
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(message: 'Something went wrong. Unable to load reports.', onRetry: _load),
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
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOwnerManagementScreen())),
                        ),
                        AppStatCard(
                          icon: Icons.store_mall_directory_rounded,
                          value: _summary.totalBusinesses.toString(),
                          label: 'Total Businesses',
                          bg: const Color(0xFFE1F7E8),
                          fg: const Color(0xFF2E7D32),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBusinessListScreen())),
                        ),
                        AppStatCard(
                          icon: Icons.groups_2_rounded,
                          value: _summary.totalCustomers.toString(),
                          label: 'Total Customers',
                          bg: const Color(0xFFE1F0FF),
                          fg: const Color(0xFF3B82F6),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: false))),
                        ),
                        AppStatCard(
                          icon: Icons.verified_user_rounded,
                          value: _summary.activeCustomers.toString(),
                          label: 'Active Customers',
                          bg: const Color(0xFFFFF1DC),
                          fg: const Color(0xFFC9820A),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: true))),
                        ),
                      ],
                    ),
              if (!_loading) ...[
                const SizedBox(height: AppSpacing.xl),
                const AppEmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Revenue Reports Coming Soon',
                  message: 'Platform-wide revenue and order totals need a new backend aggregate query, which is out of scope for this UI pass.',
                ),
              ],
            ],
          ),
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
