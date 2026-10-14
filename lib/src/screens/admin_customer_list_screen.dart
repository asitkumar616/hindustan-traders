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

  Future<void> _confirmDeleteCustomer(AdminCustomerRecord customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this customer?'),
        content: Text(
          '${customer.displayName} will no longer be able to log in or order from ${customer.businessName}. '
          'Their order history and invoices are kept exactly as they are -- nothing is deleted -- and this can be '
          'undone with Restore. Any other businesses they shop with are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AdminDashboardService.deleteCustomer(customer.customerId);
      await _loadCustomers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to delete customer: $error')));
    }
  }

  Future<void> _restoreCustomer(AdminCustomerRecord customer) async {
    try {
      await AdminDashboardService.restoreCustomer(customer.customerId);
      await _loadCustomers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer restored.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to restore customer: $error')));
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
                                child: _CustomerCard(
                                  customer: customer,
                                  onDelete: () => _confirmDeleteCustomer(customer),
                                  onRestore: () => _restoreCustomer(customer),
                                ),
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
  const _CustomerCard({required this.customer, required this.onDelete, required this.onRestore});

  final AdminCustomerRecord customer;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    if (customer.isDeleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFCE4E4), borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: const Text('Deleted', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
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
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  onDelete();
                case 'restore':
                  onRestore();
              }
            },
            itemBuilder: (_) => [
              if (customer.isDeleted)
                const PopupMenuItem(value: 'restore', child: Text('Restore'))
              else
                const PopupMenuItem(value: 'delete', child: Text('Delete customer', style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
    );
  }
}
