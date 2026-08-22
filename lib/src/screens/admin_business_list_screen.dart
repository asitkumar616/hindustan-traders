import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_flat_bottom_nav.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_voice_bottom_nav.dart' show AppNavItem;
import 'admin_customer_list_screen.dart';
import 'admin_owner_management_screen.dart';

class AdminBusinessListScreen extends StatefulWidget {
  const AdminBusinessListScreen({super.key});

  @override
  State<AdminBusinessListScreen> createState() => _AdminBusinessListScreenState();
}

class _AdminBusinessListScreenState extends State<AdminBusinessListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _query = '';
  List<AdminBusinessRecord> _businesses = const <AdminBusinessRecord>[];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _loading = true);
    try {
      final businesses = await AdminDashboardService.listBusinesses(query: _query.isEmpty ? null : _query);
      if (!mounted) return;
      setState(() => _businesses = businesses);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load businesses: $error')),
      );
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.textPrimary,
                      ),
                      const Expanded(child: Text('Businesses', style: AppTextStyles.heading)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (value) {
                        setState(() => _query = value.trim());
                        _loadBusinesses();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search businesses by name, owner, or phone',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            _loadBusinesses();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBusinesses,
                child: _loading
                    ? const AppLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        children: [
                          if (_businesses.isEmpty)
                            const AppEmptyState(icon: Icons.store_mall_directory_outlined, title: 'No Businesses Found', message: 'Try a different search.')
                          else
                            ..._businesses.map(
                              (business) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _BusinessCard(business: business),
                              ),
                            ),
                        ],
                      ),
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
          const AppNavItem(icon: Icons.store_mall_directory_rounded, label: 'Businesses', active: true),
          AppNavItem(icon: Icons.groups_2_outlined, label: 'Customers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: false)))),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business});

  final AdminBusinessRecord business;

  @override
  Widget build(BuildContext context) {
    final isActive = business.businessStatus == 'active';

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.adminPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.store_mall_directory_rounded, color: AppColors.adminPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business.businessName, style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text('${business.ownerName} · ${business.ownerPhone}', style: AppTextStyles.bodyMuted),
                if (business.businessAddress?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(business.businessAddress!, style: AppTextStyles.bodyMuted, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFE1F7E8) : AppColors.divider,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        isActive ? 'Active' : business.businessStatus,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text('${business.customerCount} Customers', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
