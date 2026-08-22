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
import 'admin_business_list_screen.dart';
import 'admin_owner_management_screen.dart';

class AdminCustomerListScreen extends StatefulWidget {
  const AdminCustomerListScreen({super.key, required this.onlyActive});

  final bool onlyActive;

  @override
  State<AdminCustomerListScreen> createState() => _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _query = '';
  List<AdminCustomerRecord> _customers = const <AdminCustomerRecord>[];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    try {
      final customers = await AdminDashboardService.listCustomers(
        query: _query.isEmpty ? null : _query,
        activeOnly: widget.onlyActive,
      );
      if (!mounted) return;
      setState(() => _customers = customers);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load customers: $error')),
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
                      Expanded(
                        child: Text(widget.onlyActive ? 'Active Customers' : 'Customers', style: AppTextStyles.heading),
                      ),
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
                        _loadCustomers();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search customers by name, shop, phone, or business',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            _loadCustomers();
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
                onRefresh: _loadCustomers,
                child: _loading
                    ? const AppLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        children: [
                          if (_customers.isEmpty)
                            AppEmptyState(
                              icon: Icons.groups_2_outlined,
                              title: 'No Customers Found',
                              message: widget.onlyActive ? 'No active customers match this search.' : 'Try a different search.',
                            )
                          else
                            ..._customers.map(
                              (customer) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _CustomerCard(customer: customer),
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
          AppNavItem(icon: Icons.store_mall_directory_outlined, label: 'Businesses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBusinessListScreen()))),
          const AppNavItem(icon: Icons.groups_2_rounded, label: 'Customers', active: true),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final AdminCustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.adminPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: AppColors.adminPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.displayName, style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text(
                  customer.phone?.isNotEmpty == true ? customer.phone! : 'No phone',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 2),
                Text(customer.businessName, style: AppTextStyles.bodyMuted, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: customer.isActive ? const Color(0xFFE1F7E8) : AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    customer.isActive ? 'Active' : customer.status,
                    style: TextStyle(
                      color: customer.isActive ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
