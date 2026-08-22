import 'package:flutter/material.dart';
import '../src/screens/login_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_dashboard_service.dart';
import '../src/services/order_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_error_state.dart';
import '../src/widgets/app_filter_chip.dart';
import '../src/widgets/app_loading_state.dart';
import '../src/widgets/app_voice_bottom_nav.dart';
import '../src/widgets/voice_order_card.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  List<CustomerBusiness> _businesses = const <CustomerBusiness>[];
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _loadError;
  String _selectedBusinessId = 'all';

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
      final businesses = await CustomerDashboardService.fetchMyBusinesses();
      final orders = await OrderService.getOrdersForCustomer();
      if (!mounted) return;
      setState(() {
        _businesses = businesses;
        _orders = orders;
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

  void _showVoiceOrder() {
    if (_businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a shop first, then you can place a voice order.')),
      );
      return;
    }
    final business = _businesses.length == 1
        ? _businesses.first
        : null;
    if (business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a shop from My Shops to place a voice order there.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: VoiceOrderCard(businessId: business.businessId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _selectedBusinessId == 'all'
        ? _orders
        : _orders.where((order) => order['business_id']?.toString() == _selectedBusinessId).toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xl, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                  const Expanded(child: Text('Orders', style: AppTextStyles.heading)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            if (_businesses.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: [
                    AppFilterChip(
                      label: 'All',
                      selected: _selectedBusinessId == 'all',
                      onTap: () => setState(() => _selectedBusinessId = 'all'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ..._businesses.expand((business) => [
                          AppFilterChip(
                            label: business.businessName,
                            selected: _selectedBusinessId == business.businessId,
                            onTap: () => setState(() => _selectedBusinessId = business.businessId),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const AppLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        children: [
                          if (_loadError != null)
                            AppErrorState(
                              message: 'Something went wrong. Unable to load your orders.',
                              onRetry: _load,
                            )
                          else if (filteredOrders.isEmpty)
                            const AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No Orders Yet',
                              message: 'Orders you place will show up here.',
                            )
                          else
                            ...filteredOrders.map(
                              (order) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OrderCard(order: order, businesses: _businesses),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.primary,
        accentLight: AppColors.primaryLight,
        leftItems: [
          AppNavItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.maybePop(context)),
          AppNavItem(icon: Icons.storefront_outlined, label: 'My Shops', onTap: () => Navigator.maybePop(context)),
        ],
        rightItems: [
          const AppNavItem(icon: Icons.receipt_long_outlined, label: 'Orders', active: true),
          AppNavItem(icon: Icons.person_outline_rounded, label: 'Profile', onTap: _logout),
        ],
        onVoice: _showVoiceOrder,
      ),
    );
  }
}


class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.businesses});

  final Map<String, dynamic> order;
  final List<CustomerBusiness> businesses;

  @override
  Widget build(BuildContext context) {
    final businessId = order['business_id']?.toString() ?? '';
    final matches = businesses.where((business) => business.businessId == businessId);
    final businessName = matches.isNotEmpty ? matches.first.businessName : 'Shop';
    final orderNumber = (order['id']?.toString() ?? '').replaceAll('-', '');
    final shortNumber = orderNumber.length >= 6 ? orderNumber.substring(0, 6).toUpperCase() : orderNumber.toUpperCase();
    final itemCount = (order['order_items'] as List<dynamic>?)?.length ?? 0;
    final amount = (order['total_amount'] as num?) ?? 0;
    final status = (order['status'] as String?) ?? 'pending';
    final placedAt = OrderService.formatDisplayDate(order['created_at'] as String?);
    final statusStyle = _statusStyleFor(status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Order #$shortNumber', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              Text('₹${formatIndianAmount(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$businessName · $placedAt · $itemCount Items',
                  style: AppTextStyles.bodyMuted,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusStyle.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text(statusStyle.label, style: TextStyle(color: statusStyle.fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyleFor(String status) {
    switch (status) {
      case 'pending':
        return const _StatusStyle('Pending', Color(0xFFFFF1DC), Color(0xFFC9820A));
      case 'ready':
        return const _StatusStyle('Ready', Color(0xFFE1F0FF), Color(0xFF3B82F6));
      case 'completed':
        return const _StatusStyle('Completed', Color(0xFFE1F7E8), Color(0xFF2E7D32));
      case 'cancelled':
        return const _StatusStyle('Cancelled', Color(0xFFFCE4E4), Color(0xFFC62828));
      default:
        return _StatusStyle(status, AppColors.divider, AppColors.textSecondary);
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}
