import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../src/screens/login_screen.dart';
import '../src/screens/owner_customer_management_screen.dart';
import '../src/screens/owner_orders_screen.dart';
import '../src/screens/owner_product_management_screen.dart';
import '../src/screens/owner_reports_screen.dart';
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
import '../src/widgets/app_voice_bottom_nav.dart' show AppNavItem;
import '../src/widgets/notification_bell.dart';
import '../src/widgets/notifications_card.dart';
import '../src/widgets/dashboard_bottom_nav.dart';
import '../src/widgets/dashboard_quick_action_tile.dart';
import '../src/widgets/owner_nav_drawer.dart';

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

  Future<void> _showNotifications() {
    return showModalBottomSheet<void>(
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
    final now = DateTime.now();
    final today = _DayStats.forDay(_orders, now);
    final yesterday = _DayStats.forDay(_orders, now.subtract(const Duration(days: 1)));
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
            children: [
              _DashboardHeader(
                businessName: _summary.businessName,
                ownerName: _ownerName,
                businessId: businessId,
                onBusinessTap: _openMenu,
                onNotificationsTap: _showNotifications,
              ),
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  message: 'Something went wrong. Unable to load your dashboard.',
                  onRetry: _loadDashboard,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _GreetingCard(),
              const SizedBox(height: AppSpacing.lg),
              _MetricGrid(
                today: today,
                yesterday: yesterday,
                loading: _isLoading,
                onTapOrders: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId, todayOnly: true)) : null,
                onTapRevenue: hasBusiness ? () => _push(OwnerTransactionsScreen(businessId: businessId, todayOnly: true)) : null,
                onTapPaid: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId, todayOnly: true)) : null,
                onTapPending: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId, todayOnly: true)) : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Order Status', style: AppTextStyles.subheading),
                  Text('Today', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _OrderStatusRow(
                stats: today,
                onTap: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId, todayOnly: true)) : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Quick Actions', style: AppTextStyles.subheading),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.add_box_rounded,
                      label: 'Add Product',
                      accentColor: AppColors.categoryDal,
                      onTap: hasBusiness
                          ? () => _push(OwnerProductManagementScreen(businessId: businessId, autoOpenAdd: true))
                          : () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.receipt_long_rounded,
                      label: 'View Orders',
                      accentColor: AppColors.danger,
                      onTap: () => _push(OwnerOrdersScreen(businessId: businessId)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.people_alt_rounded,
                      label: 'Customers',
                      accentColor: AppColors.info,
                      onTap: () => _push(OwnerCustomerManagementScreen(businessId: businessId)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      accentColor: AppColors.success,
                      onTap: () => _push(OwnerReportsScreen(businessId: businessId)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Orders', style: AppTextStyles.subheading),
                  TextButton(
                    onPressed: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId)) : null,
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_isLoading)
                const AppLoadingState()
              else if (recentOrders.isEmpty)
                const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Orders Yet',
                  message: 'Orders placed by your customers will show up here.',
                )
              else
                ...recentOrders.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RecentOrderCard(
                      order: entry.value,
                      avatarIndex: entry.key,
                      onTap: () => _push(OwnerOrdersScreen(businessId: businessId)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        items: [
          const AppNavItem(icon: Icons.home_rounded, label: 'Dashboard', active: true),
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: hasBusiness ? () => _push(OwnerOrdersScreen(businessId: businessId)) : null,
          ),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onTap: hasBusiness ? () => _push(OwnerProductManagementScreen(businessId: businessId)) : null,
          ),
          AppNavItem(
            icon: Icons.people_alt_outlined,
            label: 'Customers',
            onTap: () => _push(OwnerCustomerManagementScreen(businessId: businessId)),
          ),
          AppNavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: _openMenu),
        ],
      ),
    );
  }
}

/// Same-day order counts/amounts derived from the already-fetched order
/// list, bucketed by the order's local calendar day. Used for both "today"
/// and "yesterday" (for the vs-yesterday deltas) so every figure on the
/// dashboard stays internally consistent -- paid + pending + cancelled
/// always equals total, unlike mixing this with the RPC's IST-bucketed
/// totals would.
class _DayStats {
  const _DayStats({
    required this.total,
    required this.paid,
    required this.pending,
    required this.cancelled,
    required this.paidAmount,
    required this.pendingAmount,
  });

  final int total;
  final int paid;
  final int pending;
  final int cancelled;
  final double paidAmount;
  final double pendingAmount;

  static _DayStats forDay(List<Map<String, dynamic>> orders, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    var total = 0, paid = 0, pending = 0, cancelled = 0;
    var paidAmount = 0.0, pendingAmount = 0.0;

    for (final order in orders) {
      final createdRaw = order['created_at']?.toString();
      final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
      if (created == null || created.isBefore(start) || !created.isBefore(end)) continue;

      total++;
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
      final status = order['status'] as String? ?? 'pending';
      final paymentStatus = order['payment_status'] as String? ?? 'pending';

      if (status == 'cancelled') {
        cancelled++;
      } else if (paymentStatus == 'paid') {
        paid++;
        paidAmount += amount;
      } else {
        pending++;
        pendingAmount += amount;
      }
    }

    return _DayStats(
      total: total,
      paid: paid,
      pending: pending,
      cancelled: cancelled,
      paidAmount: paidAmount,
      pendingAmount: pendingAmount,
    );
  }
}

/// Percentage change of [today] vs [yesterday], or null when there's no
/// yesterday figure to compare against (so the caller can hide the badge
/// instead of showing a fabricated 0%/∞%).
int? _percentDelta(num today, num yesterday) {
  if (yesterday == 0) return null;
  return (((today - yesterday) / yesterday) * 100).round();
}

/// Header row: brand mark + tagline on the left, the owner's business name
/// (tap to open the nav drawer -- there's no multi-business switcher yet)
/// with role label and the notification bell on the right.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.businessName,
    required this.ownerName,
    required this.businessId,
    required this.onBusinessTap,
    required this.onNotificationsTap,
  });

  final String businessName;
  final String? ownerName;
  final String businessId;
  final VoidCallback onBusinessTap;
  final Future<void> Function() onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final displayName = businessName.isEmpty
        ? (ownerName?.isNotEmpty == true ? ownerName! : 'Your Shop')
        : businessName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/images/branding/logo.png', width: 28, height: 28, fit: BoxFit.contain),
        const SizedBox(width: AppSpacing.sm),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'OdiaTraders',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1),
            ),
            Text(
              'Wholesale Made Simple',
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary, height: 1.2),
            ),
          ],
        ),
        const Spacer(),
        InkWell(
          onTap: onBusinessTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 108),
                      child: Text(
                        displayName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const Text('Owner', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(height: 26, width: 1, color: AppColors.divider),
        NotificationBell(businessIds: [businessId], onTap: onNotificationsTap),
      ],
    );
  }
}

/// Compact cream greeting banner. Deliberately not the large saturated
/// orange gradient used elsewhere in the app -- this screen's reference
/// mockup calls for a quieter, low-chrome header treatment.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_greeting, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                const Text(
                  "Here's what's happening with your business today.",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
          ),
        ],
      ),
    );
  }
}

/// 2x2 KPI grid -- Today's Orders / Today's Revenue / Paid Orders / Pending
/// Payment. Each card is a compact horizontal composition (icon beside
/// label+value) rather than the stacked layout used elsewhere in the app.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.today,
    required this.yesterday,
    required this.loading,
    required this.onTapOrders,
    required this.onTapRevenue,
    required this.onTapPaid,
    required this.onTapPending,
  });

  final _DayStats today;
  final _DayStats yesterday;
  final bool loading;
  final VoidCallback? onTapOrders;
  final VoidCallback? onTapRevenue;
  final VoidCallback? onTapPaid;
  final VoidCallback? onTapPending;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricCard(
        icon: Icons.shopping_cart_rounded,
        bg: AppColors.statOrdersBg,
        fg: AppColors.statOrdersFg,
        label: "Today's Orders",
        value: loading ? '—' : today.total.toString(),
        deltaPercent: loading ? null : _percentDelta(today.total, yesterday.total),
        onTap: onTapOrders,
      ),
      _MetricCard(
        icon: Icons.currency_rupee_rounded,
        bg: const Color(0xFFE1F7E8),
        fg: AppColors.success,
        label: "Today's Revenue",
        value: loading ? '—' : '₹${formatIndianAmount(today.paidAmount)}',
        deltaPercent: loading ? null : _percentDelta(today.paidAmount, yesterday.paidAmount),
        onTap: onTapRevenue,
      ),
      _MetricCard(
        icon: Icons.payments_rounded,
        bg: AppColors.statCustomersBg,
        fg: AppColors.statCustomersFg,
        label: 'Paid Orders',
        value: loading ? '—' : today.paid.toString(),
        subValue: loading ? null : '₹${formatIndianAmount(today.paidAmount)}',
        onTap: onTapPaid,
      ),
      _MetricCard(
        icon: Icons.schedule_rounded,
        bg: AppColors.statPendingBg,
        fg: AppColors.statPendingFg,
        label: 'Pending Payment',
        value: loading ? '—' : today.pending.toString(),
        subValue: loading ? null : '₹${formatIndianAmount(today.pendingAmount)}',
        onTap: onTapPending,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.9,
      children: items,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.label,
    required this.value,
    this.subValue,
    this.deltaPercent,
    this.onTap,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final String label;
  final String value;
  final String? subValue;
  final int? deltaPercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (deltaPercent != null) ...[
                  const SizedBox(height: 2),
                  _DeltaCaption(percent: deltaPercent!),
                ] else if (subValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subValue!,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaCaption extends StatelessWidget {
  const _DeltaCaption({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    if (percent == 0) {
      return const Text(
        'No change · vs yesterday',
        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        overflow: TextOverflow.ellipsis,
      );
    }
    final isUp = percent > 0;
    final color = isUp ? AppColors.success : AppColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 11, color: color),
        Flexible(
          child: Text(
            '${percent.abs()}% vs yesterday',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OrderStatusRow extends StatelessWidget {
  const _OrderStatusRow({required this.stats, required this.onTap});

  final _DayStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      _OrderStatusItem(icon: Icons.shopping_cart_rounded, fg: AppColors.statOrdersFg, label: 'Total', value: stats.total),
      _OrderStatusItem(icon: Icons.check_circle_rounded, fg: AppColors.success, label: 'Paid', value: stats.paid),
      _OrderStatusItem(icon: Icons.schedule_rounded, fg: AppColors.statPendingFg, label: 'Pending', value: stats.pending),
      _OrderStatusItem(icon: Icons.cancel_rounded, fg: AppColors.danger, label: 'Cancelled', value: stats.cancelled),
    ];

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AppCard(
                  onTap: onTap,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: AppSpacing.xs),
                  child: Column(
                    children: [
                      Icon(item.icon, size: 16, color: item.fg),
                      const SizedBox(height: 5),
                      Text(item.value.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 1),
                      Text(item.label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _OrderStatusItem {
  const _OrderStatusItem({required this.icon, required this.fg, required this.label, required this.value});
  final IconData icon;
  final Color fg;
  final String label;
  final int value;
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.avatarIndex, required this.onTap});

  final Map<String, dynamic> order;
  final int avatarIndex;
  final VoidCallback onTap;

  static const _avatarColors = [AppColors.info, AppColors.success, AppColors.primary, AppColors.categoryDal];

  @override
  Widget build(BuildContext context) {
    final customer = (order['customer'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final customerName = (customer['name'] as String?)?.isNotEmpty == true ? customer['name'] as String : 'Customer';
    final items = (order['order_items'] as List<dynamic>?) ?? const <dynamic>[];
    final amount = (order['total_amount'] as num?) ?? 0;
    final orderId = order['id']?.toString() ?? '';
    final orderRef = orderId.length >= 6 ? 'OM${orderId.substring(0, 6).toUpperCase()}' : 'OM${orderId.toUpperCase()}';
    final createdRaw = order['created_at']?.toString();
    final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
    final timeLabel = created == null ? '' : DateFormat('h:mm a').format(created);
    final paymentBadge = _paymentBadge(order);
    final avatarColor = _avatarColors[avatarIndex % _avatarColors.length];

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: avatarColor.withValues(alpha: 0.15), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
              style: TextStyle(color: avatarColor, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(orderRef, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary)),
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(timeLabel, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$customerName · ${items.length} item${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${formatIndianAmount(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: paymentBadge.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(paymentBadge.icon, size: 11, color: paymentBadge.fg),
                    const SizedBox(width: 3),
                    Text(paymentBadge.label, style: TextStyle(color: paymentBadge.fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }

  _PaymentBadge _paymentBadge(Map<String, dynamic> order) {
    final method = order['payment_method']?.toString();
    final status = order['payment_status']?.toString() ?? 'pending';
    final methodLabel = switch (method) {
      'upi' => 'UPI',
      'cash_on_delivery' => 'Cash',
      _ => 'Payment',
    };
    final statusLabel = status.isEmpty ? 'Pending' : '${status[0].toUpperCase()}${status.substring(1)}';
    final label = '$methodLabel • $statusLabel';

    return switch (status) {
      'paid' => _PaymentBadge(label, const Color(0xFFE1F7E8), AppColors.success, Icons.check_circle_rounded),
      'failed' => _PaymentBadge(label, const Color(0xFFFCE4E4), AppColors.danger, Icons.error_rounded),
      _ => _PaymentBadge(label, AppColors.statPendingBg, AppColors.statPendingFg, Icons.schedule_rounded),
    };
  }
}

class _PaymentBadge {
  const _PaymentBadge(this.label, this.bg, this.fg, this.icon);
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;
}
