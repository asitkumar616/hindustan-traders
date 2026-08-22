import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_voice_bottom_nav.dart';
import '../widgets/owner_nav_drawer.dart';
import '../widgets/voice_order_card.dart';
import 'login_screen.dart';
import 'owner_orders_screen.dart';
import 'owner_product_management_screen.dart';

class OwnerReportsScreen extends StatefulWidget {
  const OwnerReportsScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _ReportBucket {
  _ReportBucket(this.label, this.sortKey);
  final String label;
  final String sortKey;
  int orderCount = 0;
  double revenue = 0;
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  bool _monthly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await OrderService.getOrdersForBusiness(widget.businessId);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  List<_ReportBucket> _buildBuckets() {
    final buckets = <String, _ReportBucket>{};

    for (final order in _orders) {
      final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '')?.toLocal();
      if (createdAt == null) continue;

      final key = _monthly
          ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}'
          : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      final label = _monthly ? _monthLabel(createdAt) : _dayLabel(createdAt);

      final bucket = buckets.putIfAbsent(key, () => _ReportBucket(label, key));
      bucket.orderCount += 1;
      bucket.revenue += ((order['total_amount'] as num?) ?? 0).toDouble();
    }

    final list = buckets.values.toList()..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return list;
  }

  String _dayLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
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

  void _showVoiceOrderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: VoiceOrderCard(businessId: widget.businessId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets();
    final totalRevenue = buckets.fold<double>(0, (sum, bucket) => sum + bucket.revenue);
    final totalOrders = buckets.fold<int>(0, (sum, bucket) => sum + bucket.orderCount);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surfaceMuted,
      drawer: OwnerNavDrawer(
        businessId: widget.businessId,
        onDashboard: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onNavigate: (screen) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),
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
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  AppFilterChip(
                    label: 'Day-wise',
                    selected: !_monthly,
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _monthly = false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Month-wise',
                    selected: _monthly,
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _monthly = true),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const AppLoadingState()
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Revenue', style: AppTextStyles.bodyMuted),
                            const SizedBox(height: 4),
                            Text('₹${formatIndianAmount(totalRevenue)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Orders', style: AppTextStyles.bodyMuted),
                            const SizedBox(height: 4),
                            Text(totalOrders.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if (buckets.isEmpty)
                  const AppEmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: 'No Orders Yet',
                    message: 'Once orders come in, they will be broken down here by day or month.',
                  )
                else
                  ...buckets.map(
                    (bucket) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bucket.label, style: AppTextStyles.subheading),
                                  const SizedBox(height: 2),
                                  Text('${bucket.orderCount} Orders', style: AppTextStyles.bodyMuted),
                                ],
                              ),
                            ),
                            Text(
                              '₹${formatIndianAmount(bucket.revenue)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ownerPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.ownerPrimaryDark,
        accentLight: AppColors.ownerPrimaryLight,
        leftItems: [
          AppNavItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.maybePop(context)),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerProductManagementScreen(businessId: widget.businessId))),
          ),
        ],
        rightItems: [
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerOrdersScreen(businessId: widget.businessId))),
          ),
          AppNavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: () => _scaffoldKey.currentState?.openDrawer()),
        ],
        onVoice: _showVoiceOrderSheet,
      ),
    );
  }
}
