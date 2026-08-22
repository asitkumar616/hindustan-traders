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
import 'owner_product_management_screen.dart';

class OwnerOrdersScreen extends StatefulWidget {
  const OwnerOrdersScreen({super.key, required this.businessId, this.todayOnly = false});

  final String businessId;
  final bool todayOnly;

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final orders = await OrderService.getOrdersForBusiness(widget.businessId);
      final filtered = widget.todayOnly ? orders.where(_isToday).toList() : orders;
      if (!mounted) return;
      setState(() => _orders = filtered);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load orders: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isToday(Map<String, dynamic> order) {
    final createdAt = order['created_at'] as String?;
    if (createdAt == null) return false;
    final parsed = DateTime.tryParse(createdAt)?.toLocal();
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.year == now.year && parsed.month == now.month && parsed.day == now.day;
  }

  Future<void> _updateStatus(Map<String, dynamic> order, String status) async {
    try {
      await OrderService.updateStatus(
        order['id'] as String,
        status,
        customerId: order['customer_id'] as String?,
        businessId: order['business_id'] as String?,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await _loadOrders();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update order: $error')),
      );
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final customer = (order['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final customerName = (customer['name'] as String?) ?? 'Customer';
    final customerPhone = (customer['phone'] as String?) ?? '';
    final items = (order['order_items'] as List<dynamic>?) ?? const <dynamic>[];
    final createdAt = OrderService.formatDisplayDate(order['created_at'] as String?);
    final status = (order['status'] as String?) ?? 'pending';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${order['id']?.toString().substring(0, 8) ?? 'n/a'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Customer: $customerName${customerPhone.isEmpty ? '' : ' • $customerPhone'}'),
              const SizedBox(height: 6),
              Text('Placed: $createdAt'),
              const SizedBox(height: 8),
              Text('Status: ${status.toUpperCase()}'),
              const SizedBox(height: 12),
              const Text('Items:'),
              const SizedBox(height: 4),
              if (items.isEmpty)
                const Text('No item breakdown available yet.')
              else
                ...items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  final product = (itemMap['product'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                  final productName = (product['name'] as String?) ?? 'Product';
                  final qty = itemMap['quantity'] ?? 0;
                  final amount = itemMap['amount'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $productName × $qty • ₹$amount'),
                  );
                }),
              const SizedBox(height: 12),
              Text('Total: ₹${(order['total_amount'] as num? ?? 0).toStringAsFixed(0)}'),
              const SizedBox(height: 16),
              if (status == 'pending')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(order, 'ready'),
                    child: const Text('Approve • Mark ready'),
                  ),
                )
              else if (status == 'ready')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(order, 'completed'),
                    child: const Text('Close order • Mark complete'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
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
    final filteredOrders = _statusFilter == 'all'
        ? _orders
        : _orders.where((order) => (order['status'] as String? ?? 'pending') == _statusFilter).toList();

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
        onLogout: () async {
          Navigator.pop(context);
          await AuthService.signOut();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
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
                  Expanded(
                    child: Text(widget.todayOnly ? "Today's Orders" : 'Orders', style: AppTextStyles.heading),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                children: [
                  AppFilterChip(
                    label: 'All',
                    selected: _statusFilter == 'all',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'all'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Pending',
                    selected: _statusFilter == 'pending',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'pending'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Ready',
                    selected: _statusFilter == 'ready',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'ready'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Completed',
                    selected: _statusFilter == 'completed',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'completed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadOrders,
                child: _loading
                    ? const AppLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        children: [
                          if (filteredOrders.isEmpty)
                            AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No Orders',
                              message: widget.todayOnly ? 'No orders placed today yet.' : 'No orders match this filter yet.',
                            )
                          else
                            ...filteredOrders.map(
                              (order) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OwnerOrderCard(order: order, onTap: () => _showOrderDetails(order)),
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
        accentDark: AppColors.ownerPrimaryDark,
        accentLight: AppColors.ownerPrimaryLight,
        leftItems: [
          AppNavItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.maybePop(context)),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OwnerProductManagementScreen(businessId: widget.businessId)),
            ),
          ),
        ],
        rightItems: [
          const AppNavItem(icon: Icons.receipt_long_rounded, label: 'Orders', active: true),
          AppNavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: () => _scaffoldKey.currentState?.openDrawer()),
        ],
        onVoice: _showVoiceOrderSheet,
      ),
    );
  }
}

class _OwnerOrderCard extends StatelessWidget {
  const _OwnerOrderCard({required this.order, required this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final customer = (order['customer'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final customerName = (customer['name'] as String?)?.isNotEmpty == true ? customer['name'] as String : 'Customer';
    final items = (order['order_items'] as List<dynamic>?) ?? const <dynamic>[];
    final amount = (order['total_amount'] as num?) ?? 0;
    final status = (order['status'] as String?) ?? 'pending';
    final placedAt = OrderService.formatDisplayDate(order['created_at'] as String?);
    final orderNumber = (order['id']?.toString() ?? '').replaceAll('-', '');
    final shortNumber = orderNumber.length >= 6 ? orderNumber.substring(0, 6).toUpperCase() : orderNumber.toUpperCase();
    final statusStyle = _statusStyleFor(status);

    return AppCard(
      onTap: onTap,
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
          const SizedBox(height: 2),
          Text(customerName, style: AppTextStyles.subheading),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text('$placedAt · ${items.length} Items', style: AppTextStyles.bodyMuted, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusStyle.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(statusStyle.label, style: TextStyle(color: statusStyle.fg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
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
