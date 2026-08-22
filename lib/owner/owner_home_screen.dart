import 'package:flutter/material.dart';
import '../src/screens/login_screen.dart';
import '../src/screens/owner_customer_management_screen.dart';
import '../src/screens/owner_orders_screen.dart';
import '../src/screens/owner_product_management_screen.dart';
import '../src/screens/owner_transactions_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/order_service.dart';
import '../src/services/owner_dashboard_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_error_state.dart';
import '../src/widgets/app_loading_state.dart';
import '../src/widgets/app_quick_action_tile.dart';
import '../src/widgets/app_voice_bottom_nav.dart';
import '../src/widgets/ask_assistant_sheet.dart';
import '../src/widgets/notifications_card.dart';
import '../src/widgets/owner_nav_drawer.dart';
import '../src/widgets/voice_order_card.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _ownerName;
  OwnerDashboardSummary _summary = OwnerDashboardSummary.empty;
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await AuthService.getCurrentProfile();
      final summary = await OwnerDashboardService.fetchSummary();
      final orders = summary.businessId.isEmpty
          ? const <Map<String, dynamic>>[]
          : await OrderService.getOrdersForBusiness(summary.businessId);

      if (!mounted) return;
      setState(() {
        _ownerName = profile?.name;
        _summary = summary;
        _orders = orders;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  void _openMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(
          top: false,
          child: NotificationsCard(businessId: _summary.businessId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessId = _summary.businessId;
    final hasBusiness = businessId.isNotEmpty && !_isLoading;
    final pendingOrders = _orders.where((order) => (order['status'] as String? ?? 'pending') != 'completed').length;
    final recentOrders = _orders.take(3).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surfaceMuted,
      drawer: OwnerNavDrawer(
        businessId: businessId,
        onDashboard: () => Navigator.pop(context),
        onNavigate: (screen) {
          Navigator.pop(context);
          _push(screen);
        },
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _openMenu,
                    icon: const Icon(Icons.menu_rounded),
                    color: AppColors.textPrimary,
                  ),
                  IconButton(
                    onPressed: _showNotifications,
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: AppColors.ownerPrimary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _summary.businessName.isEmpty
                          ? (_ownerName?.isNotEmpty == true ? _ownerName! : 'Your Shop')
                          : _summary.businessName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  message: 'Something went wrong. Unable to load your dashboard.',
                  onRetry: _loadDashboard,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _RevenueHeroCard(
                amount: _summary.todayRevenue,
                loading: _isLoading,
                onTap: hasBusiness
                    ? () => _push(OwnerTransactionsScreen(businessId: businessId, todayOnly: true))
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              _StatGrid(
                summary: _summary,
                pendingOrders: pendingOrders,
                onTapCustomers: () => _push(OwnerCustomerManagementScreen(businessId: businessId)),
                onTapOrders: () => _push(OwnerOrdersScreen(businessId: businessId, todayOnly: true)),
                onTapPending: () => _push(OwnerOrdersScreen(businessId: businessId)),
                onTapPendingAmount: () => _push(OwnerCustomerManagementScreen(businessId: businessId, onlyOutstanding: true)),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('QUICK ACTIONS', style: AppTextStyles.sectionLabel),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.5,
                children: [
                  AppQuickActionTile(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Order',
                    accentColor: AppColors.ownerPrimary,
                    onTap: hasBusiness ? () => _showOrderChooser(businessId) : () {},
                  ),
                  AppQuickActionTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer',
                    accentColor: AppColors.ownerPrimary,
                    onTap: () => _push(OwnerCustomerManagementScreen(businessId: businessId)),
                  ),
                  AppQuickActionTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Product',
                    accentColor: AppColors.ownerPrimary,
                    onTap: hasBusiness ? () => _push(OwnerProductManagementScreen(businessId: businessId)) : () {},
                  ),
                  AppQuickActionTile(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Payment',
                    accentColor: AppColors.ownerPrimary,
                    onTap: () => _push(OwnerCustomerManagementScreen(businessId: businessId, onlyOutstanding: true)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: () => _showAssistant(businessId),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.ownerPrimaryDark, AppColors.ownerPrimaryLight],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(color: AppColors.ownerPrimary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ask Assistant', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Speak or type to get things done', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId)) : null,
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_isLoading)
                const AppLoadingState()
              else if (recentOrders.isEmpty)
                const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Orders Yet',
                  message: 'Orders placed by your customers will show up here.',
                )
              else
                ...recentOrders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _RecentOrderCard(
                      order: order,
                      onTap: () => _push(OwnerOrdersScreen(businessId: businessId)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.ownerPrimaryDark,
        accentLight: AppColors.ownerPrimaryLight,
        leftItems: [
          const AppNavItem(icon: Icons.home_rounded, label: 'Home', active: true),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onTap: hasBusiness ? () => _push(OwnerProductManagementScreen(businessId: businessId)) : null,
          ),
        ],
        rightItems: [
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId)) : null,
          ),
          AppNavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: _openMenu),
        ],
        onVoice: () => _showVoiceOrderSheet(businessId),
      ),
    );
  }

  void _showVoiceOrderSheet(String businessId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: VoiceOrderCard(businessId: businessId.isEmpty ? null : businessId)),
      ),
    );
  }

  // "Order" quick action: normal UI is the primary path here (Browse
  // Products), with Speak offered as one option rather than the whole
  // experience. There's no owner-side order-builder screen yet, so both
  // options route to the closest existing functionality for now.
  void _showOrderChooser(String businessId) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Order', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              const Text('How would you like to add items?', style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.ownerPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.mic_rounded, color: AppColors.ownerPrimary),
                ),
                title: const Text('Speak', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showVoiceOrderSheet(businessId);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.ownerPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.ownerPrimary),
                ),
                title: const Text('Browse Products', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _push(OwnerProductManagementScreen(businessId: businessId));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssistant(String businessId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => AskAssistantSheet(businessId: businessId),
    );
  }
}

class _RevenueHeroCard extends StatelessWidget {
  const _RevenueHeroCard({required this.amount, required this.loading, this.onTap});

  final double amount;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ownerPrimaryDark, AppColors.ownerPrimaryLight],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.ownerPrimary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TODAY'S REVENUE",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            loading
                ? const SizedBox(
                    height: 34,
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                  )
                : Text(
                    '₹${formatIndianAmount(amount)}',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.summary,
    required this.pendingOrders,
    required this.onTapCustomers,
    required this.onTapOrders,
    required this.onTapPending,
    required this.onTapPendingAmount,
  });

  final OwnerDashboardSummary summary;
  final int pendingOrders;
  final VoidCallback onTapCustomers;
  final VoidCallback onTapOrders;
  final VoidCallback onTapPending;
  final VoidCallback onTapPendingAmount;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        icon: Icons.groups_rounded,
        value: summary.totalCustomers.toString(),
        label: 'Customers',
        bg: AppColors.statCustomersBg,
        fg: AppColors.statCustomersFg,
        onTap: onTapCustomers,
      ),
      _StatItem(
        icon: Icons.inventory_2_rounded,
        value: summary.todayOrders.toString(),
        label: "Today's Orders",
        bg: AppColors.statOrdersBg,
        fg: AppColors.statOrdersFg,
        onTap: onTapOrders,
      ),
      _StatItem(
        icon: Icons.hourglass_bottom_rounded,
        value: pendingOrders.toString(),
        label: 'Pending Orders',
        bg: AppColors.statPendingBg,
        fg: AppColors.statPendingFg,
        onTap: onTapPending,
      ),
      _StatItem(
        icon: Icons.currency_rupee_rounded,
        value: formatIndianAmount(summary.pendingAmount),
        label: 'Pending Amount',
        bg: AppColors.statAmountBg,
        fg: AppColors.statAmountFg,
        onTap: onTapPendingAmount,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: items.map((item) => _StatCard(item: item)).toList(),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: item.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: item.bg, shape: BoxShape.circle),
            child: Icon(item.icon, size: 18, color: item.fg),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final customer = (order['customer'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final customerName = (customer['name'] as String?)?.isNotEmpty == true ? customer['name'] as String : 'Customer';
    final items = (order['order_items'] as List<dynamic>?) ?? const <dynamic>[];
    final amount = (order['total_amount'] as num?) ?? 0;
    final status = (order['status'] as String?) ?? 'pending';
    final statusStyle = _statusStyle(status);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.ownerPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.ownerPrimary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${items.length} Items', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${formatIndianAmount(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusStyle.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(
                  statusStyle.label,
                  style: TextStyle(color: statusStyle.fg, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyle(String status) {
    switch (status) {
      case 'pending':
        return const _StatusStyle('Pending', AppColors.statPendingBg, AppColors.statPendingFg);
      case 'ready':
        return const _StatusStyle('Ready', AppColors.statOrdersBg, AppColors.statOrdersFg);
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

