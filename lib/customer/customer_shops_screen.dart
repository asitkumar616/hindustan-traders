import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../src/models/cart_line.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_dashboard_service.dart';
import '../src/services/notification_service.dart';
import '../src/services/order_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/category_visuals.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_error_state.dart';
import '../src/widgets/app_loading_state.dart';
import '../src/widgets/app_quick_action_tile.dart';
import '../src/widgets/app_section_header.dart';
import '../src/widgets/app_voice_bottom_nav.dart';
import '../src/widgets/notification_bell.dart';
import '../src/widgets/voice_order_card.dart';
import 'customer_home_screen.dart';
import 'customer_orders_screen.dart';
import 'customer_profile_screen.dart';

class CustomerShopsScreen extends StatefulWidget {
  const CustomerShopsScreen({super.key});

  @override
  State<CustomerShopsScreen> createState() => _CustomerShopsScreenState();
}

class _CustomerShopsScreenState extends State<CustomerShopsScreen> {
  String? _customerName;
  List<CustomerBusiness> _businesses = const <CustomerBusiness>[];
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  List<String> _categories = const <String>[];
  List<Map<String, dynamic>> _frequentlyOrdered = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _loadError;

  final GlobalKey _shopsSectionKey = GlobalKey();

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
      final profile = await AuthService.getCurrentProfile();
      final businesses = await CustomerDashboardService.fetchMyBusinesses();
      final orders = await OrderService.getOrdersForCustomer();
      final businessIds = businesses.map((b) => b.businessId).toList();
      final results = await Future.wait([
        CustomerDashboardService.getCategoriesForBusinesses(businessIds),
        CustomerDashboardService.getFrequentlyOrderedProducts(limit: 4),
      ]);
      if (!mounted) return;
      setState(() {
        _customerName = profile?.name;
        _businesses = businesses;
        _orders = orders;
        _categories = results[0] as List<String>;
        _frequentlyOrdered = results[1] as List<Map<String, dynamic>>;
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

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  CustomerBusiness? _businessById(String businessId) {
    for (final business in _businesses) {
      if (business.businessId == businessId) return business;
    }
    return null;
  }

  void _openShop(CustomerBusiness business, {String? initialCategory, List<CartLine>? initialCartItems}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerHomeScreen(
          businessId: business.businessId,
          businessName: business.businessName,
          initialCategory: initialCategory,
          initialCartItems: initialCartItems,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  /// Shared "which shop?" prompt for any dashboard action that needs exactly
  /// one business before it can proceed (Start Shopping, a category tap, an
  /// Add-to-cart) -- skips the prompt when there's only one connected shop.
  void _pickShop({required String title, required void Function(CustomerBusiness business) onPicked}) {
    if (_businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ask a shop owner to add your mobile number as a customer to get started.')),
      );
      return;
    }
    if (_businesses.length == 1) {
      onPicked(_businesses.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.subheading),
              const SizedBox(height: AppSpacing.md),
              ..._businesses.map(
                (business) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                  title: Text(business.businessName),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onPicked(business);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startShopping() {
    _pickShop(title: 'Choose a shop', onPicked: (business) => _openShop(business));
  }

  void _shopCategory(String category) {
    _pickShop(title: 'Choose a shop for $category', onPicked: (business) => _openShop(business, initialCategory: category));
  }

  void _addFrequentlyOrdered(Map<String, dynamic> item) {
    final businessId = item['business_id']?.toString() ?? '';
    final business = _businessById(businessId);
    if (business == null) return;

    final line = CartLine(
      productId: item['product_id']?.toString() ?? '',
      variantId: item['variant_id']?.toString() ?? '',
      productName: item['product_name']?.toString() ?? 'Product',
      brand: item['brand']?.toString(),
      variantQuantity: (item['variant_quantity'] as num?)?.toDouble() ?? 1,
      variantUnit: item['variant_unit']?.toString() ?? '',
      packageType: item['package_type']?.toString() ?? 'LOOSE',
      price: (item['current_price'] as num?)?.toDouble() ?? 0,
      quantity: (item['minimum_order_quantity'] as num?)?.toDouble() ?? 1,
      minimumOrderQuantity: (item['minimum_order_quantity'] as num?)?.toDouble() ?? 1,
    );
    _openShop(business, initialCartItems: [line]);
  }

  Future<void> _reorder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString() ?? '';
    final businessId = order['business_id']?.toString() ?? '';
    final business = _businessById(businessId);
    if (orderId.isEmpty || business == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final items = await OrderService.getOrderItems(orderId);
      final variantIds = items.map((item) => item['variant_id']?.toString()).whereType<String>().where((id) => id.isNotEmpty).toSet().toList();
      final variantStates = await OrderService.getCurrentVariantStates(variantIds);

      final available = <CartLine>[];
      final unavailable = <String>[];

      for (final item in items) {
        final variantId = item['variant_id']?.toString();
        final variant = variantId != null ? variantStates[variantId] : null;
        final productName = item['product_name']?.toString() ?? 'Item';
        if (variant == null || variant['is_active'] == false) {
          unavailable.add(productName);
          continue;
        }
        final minQty = (variant['minimum_order_quantity'] as num?)?.toDouble() ?? 1;
        final orderedQty = (item['quantity'] as num?)?.toDouble() ?? 1;
        available.add(CartLine(
          productId: item['product_id']?.toString() ?? '',
          variantId: variantId!,
          productName: productName,
          brand: item['brand']?.toString(),
          variantQuantity: (item['variant_quantity'] as num?)?.toDouble() ?? 1,
          variantUnit: item['variant_unit']?.toString() ?? '',
          packageType: item['package_type']?.toString() ?? 'LOOSE',
          price: (variant['selling_price'] as num?)?.toDouble() ?? 0,
          quantity: orderedQty < minQty ? minQty : orderedQty,
          minimumOrderQuantity: minQty,
        ));
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (available.isEmpty) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Nothing to reorder'),
            content: const Text('None of the items in this order are available anymore.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
      }

      if (unavailable.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Some items are unavailable'),
            content: Text(
              'The following items are no longer available: ${unavailable.join(', ')}.\n\n'
              'Continue with the remaining ${available.length} item${available.length == 1 ? '' : 's'}?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
            ],
          ),
        );
        if (proceed != true) return;
      }

      if (!mounted) return;
      _openShop(business, initialCartItems: available);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to reorder: $error')));
    }
  }

  void _requestNewShop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requesting a new shop is coming soon. Ask the shop owner to add your number for now.')),
    );
  }

  void _openOrders() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()));
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerProfileScreen()));
  }

  void _scrollToShops() {
    final ctx = _shopsSectionKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
  }

  void _startVoiceOrder() {
    if (_businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a shop first, then you can place a voice order.')),
      );
      return;
    }
    if (_businesses.length == 1) {
      _openVoiceSheet(_businesses.first);
      return;
    }
    _pickShop(title: 'Choose a shop to speak your order', onPicked: _openVoiceSheet);
  }

  void _openVoiceSheet(CustomerBusiness business) {
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

  Future<void> _showNotifications() {
    if (_businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notifications yet.')));
      return Future.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: _NotificationsSheet(businesses: _businesses)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = _customerName?.isNotEmpty == true ? _customerName! : 'there';
    final stats = _CustomerStats.compute(_orders);
    final recentOrders = _orders.take(3).toList();

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
                  const Icon(Icons.shopping_cart_rounded, color: AppColors.categoryDal, size: 26),
                  const SizedBox(width: AppSpacing.xs),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(text: 'Odia', style: TextStyle(color: AppColors.textPrimary)),
                        TextSpan(text: 'Mandi', style: TextStyle(color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  NotificationBell(
                    businessIds: _businesses.map((b) => b.businessId).toList(),
                    onTap: _showNotifications,
                  ),
                ],
              ),
              const Text('Wholesale Made Simple', style: AppTextStyles.caption),
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  message: 'Something went wrong. Unable to load your dashboard.',
                  onRetry: _load,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _GreetingBanner(greeting: _greeting, name: greetingName),
              if (!_loading && _businesses.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _CustomerStatsGrid(
                  shopCount: _businesses.length,
                  stats: stats,
                  onTapShops: _scrollToShops,
                  onTapActiveOrders: _openOrders,
                  onTapThisMonth: _openOrders,
                  onTapPendingCod: _openOrders,
                ),
              ],
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
                    icon: Icons.storefront_outlined,
                    label: 'Start Shopping',
                    accentColor: AppColors.primary,
                    onTap: _startShopping,
                  ),
                  AppQuickActionTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'My Orders',
                    accentColor: AppColors.navy,
                    onTap: _openOrders,
                  ),
                  AppQuickActionTile(
                    icon: Icons.payments_outlined,
                    label: 'Payments',
                    accentColor: AppColors.success,
                    onTap: _openOrders,
                  ),
                  AppQuickActionTile(
                    icon: Icons.description_outlined,
                    label: 'Invoices',
                    accentColor: AppColors.categoryDal,
                    onTap: _openOrders,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _PromoBanner(
                title: 'Best Prices on Daily Essentials',
                subtitle: 'Rice, Dal, Oil, Atta and more from your trusted shops.',
                buttonLabel: 'Shop Now',
                icon: Icons.storefront_rounded,
                colors: const [AppColors.primary, AppColors.primaryLight],
                onTap: _startShopping,
              ),
              const SizedBox(height: AppSpacing.xl),
              KeyedSubtree(
                key: _shopsSectionKey,
                child: AppSectionHeader(title: 'Connected Shops', actionLabel: _businesses.isEmpty ? null : 'View All', onAction: _scrollToShops),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const AppLoadingState()
              else if (_businesses.isEmpty && _loadError == null)
                const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No Shops Connected Yet',
                  message: 'Ask a shop owner to add your mobile number as a customer to get started.',
                )
              else
                ..._businesses.map(
                  (business) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ShopCard(business: business, onTap: () => _openShop(business)),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _requestNewShop,
                icon: const Icon(Icons.add),
                label: const Text('Add / Request New Shop'),
              ),
              if (!_loading) ...[
                const SizedBox(height: AppSpacing.xl),
                AppSectionHeader(title: 'Recent Orders', actionLabel: recentOrders.isEmpty ? null : 'View All', onAction: _openOrders),
                const SizedBox(height: AppSpacing.md),
                if (recentOrders.isEmpty)
                  const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Orders Yet',
                    message: 'Start shopping to place your first order.',
                  )
                else
                  ...recentOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _RecentOrderCard(
                        order: order,
                        businessName: _businessById(order['business_id']?.toString() ?? '')?.businessName ?? 'Shop',
                        onReorder: order['status'] == 'completed' ? () => _reorder(order) : null,
                      ),
                    ),
                  ),
              ],
              if (!_loading && _categories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const AppSectionHeader(title: 'Shop by Category'),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _CategoryChip(category: category, onTap: () => _shopCategory(category));
                    },
                  ),
                ),
              ],
              if (!_loading && _frequentlyOrdered.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const AppSectionHeader(title: 'Frequently Ordered'),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _frequentlyOrdered.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = _frequentlyOrdered[index];
                      return _FrequentlyOrderedCard(item: item, onAdd: () => _addFrequentlyOrdered(item));
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _PromoBanner(
                title: 'Explore More Shops',
                subtitle: 'Get connected with more trusted wholesale shops.',
                buttonLabel: 'Add Shop',
                icon: Icons.add_business_rounded,
                colors: const [AppColors.categoryDal, AppColors.navyLight],
                onTap: _requestNewShop,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.primary,
        accentLight: AppColors.primaryLight,
        leftItems: [
          const AppNavItem(icon: Icons.home_rounded, label: 'Home', active: true),
          AppNavItem(icon: Icons.storefront_outlined, label: 'Shops', onTap: _scrollToShops),
        ],
        rightItems: [
          AppNavItem(icon: Icons.receipt_long_outlined, label: 'Orders', onTap: _openOrders),
          AppNavItem(icon: Icons.person_outline_rounded, label: 'Profile', onTap: _openProfile),
        ],
        onVoice: _startVoiceOrder,
      ),
    );
  }
}

/// Active/this-month/pending-COD figures derived from the customer's own
/// order history (already fetched for Recent Orders), rather than a
/// dedicated RPC -- keeps this screen to the one order-history request.
class _CustomerStats {
  const _CustomerStats({
    required this.activeOrders,
    required this.thisMonthTotal,
    required this.lastMonthTotal,
    required this.pendingCodCount,
    required this.pendingCodAmount,
  });

  final int activeOrders;
  final double thisMonthTotal;
  final double lastMonthTotal;
  final int pendingCodCount;
  final double pendingCodAmount;

  static _CustomerStats compute(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    var active = 0;
    var thisMonth = 0.0, lastMonth = 0.0;
    var codCount = 0;
    var codAmount = 0.0;

    for (final order in orders) {
      final status = order['status'] as String? ?? 'pending';
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
      final createdRaw = order['created_at']?.toString();
      final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();

      if (status == 'pending' || status == 'ready') active++;

      if (created != null && status != 'cancelled') {
        if (!created.isBefore(thisMonthStart)) {
          thisMonth += amount;
        } else if (!created.isBefore(lastMonthStart)) {
          lastMonth += amount;
        }
      }

      final paymentMethod = order['payment_method']?.toString();
      final paymentStatus = order['payment_status']?.toString() ?? 'pending';
      if (paymentMethod == 'cash_on_delivery' && paymentStatus == 'pending') {
        codCount++;
        codAmount += amount;
      }
    }

    return _CustomerStats(
      activeOrders: active,
      thisMonthTotal: thisMonth,
      lastMonthTotal: lastMonth,
      pendingCodCount: codCount,
      pendingCodAmount: codAmount,
    );
  }
}

int? _percentDelta(num current, num previous) {
  if (previous == 0) return null;
  return (((current - previous) / previous) * 100).round();
}

class _GreetingBanner extends StatelessWidget {
  const _GreetingBanner({required this.greeting, required this.name});

  final String greeting;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting,', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  '$name!',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  "Here's what's happening with your shops today.",
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

class _CustomerStatsGrid extends StatelessWidget {
  const _CustomerStatsGrid({
    required this.shopCount,
    required this.stats,
    required this.onTapShops,
    required this.onTapActiveOrders,
    required this.onTapThisMonth,
    required this.onTapPendingCod,
  });

  final int shopCount;
  final _CustomerStats stats;
  final VoidCallback onTapShops;
  final VoidCallback onTapActiveOrders;
  final VoidCallback onTapThisMonth;
  final VoidCallback onTapPendingCod;

  @override
  Widget build(BuildContext context) {
    final trend = _percentDelta(stats.thisMonthTotal, stats.lastMonthTotal);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: [
        _StatTile(
          icon: Icons.storefront_rounded,
          bg: AppColors.categoryDal.withValues(alpha: 0.12),
          fg: AppColors.categoryDal,
          label: 'My Shops',
          value: shopCount.toString(),
          onTap: onTapShops,
        ),
        _StatTile(
          icon: Icons.inventory_2_rounded,
          bg: AppColors.statPendingBg,
          fg: AppColors.statPendingFg,
          label: 'Active Orders',
          value: stats.activeOrders.toString(),
          onTap: onTapActiveOrders,
        ),
        _StatTile(
          icon: Icons.currency_rupee_rounded,
          bg: const Color(0xFFE1F7E8),
          fg: AppColors.success,
          label: 'This Month Purchases',
          value: '₹${formatIndianAmount(stats.thisMonthTotal)}',
          deltaPercent: trend,
          onTap: onTapThisMonth,
        ),
        _StatTile(
          icon: Icons.local_shipping_outlined,
          bg: AppColors.statAmountBg,
          fg: AppColors.statAmountFg,
          label: 'Pending COD',
          value: stats.pendingCodCount.toString(),
          subValue: '₹${formatIndianAmount(stats.pendingCodAmount)}',
          onTap: onTapPendingCod,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.label,
    required this.value,
    this.subValue,
    this.deltaPercent,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final String label;
  final String value;
  final String? subValue;
  final int? deltaPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: fg),
              ),
              if (deltaPercent != null) _DeltaChip(percent: deltaPercent!),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(
            subValue == null ? label : '$label · $subValue',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    if (percent == 0) {
      return const Text('0%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
    }
    final isUp = percent > 0;
    final color = isUp ? AppColors.success : AppColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: color),
        Text('${percent.abs()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(buttonLabel),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.business, required this.onTap});

  final CustomerBusiness business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business.businessName, style: AppTextStyles.subheading),
                if (business.customerDisplayName?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(business.customerDisplayName!, style: AppTextStyles.bodyMuted),
                ],
              ],
            ),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Shop Now', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = categoryVisual(category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(visual.icon, color: visual.color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              category,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequentlyOrderedCard extends StatelessWidget {
  const _FrequentlyOrderedCard({required this.item, required this.onAdd});

  final Map<String, dynamic> item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final name = item['product_name']?.toString() ?? 'Product';
    final brand = item['brand']?.toString();
    final qty = (item['variant_quantity'] as num?)?.toDouble();
    final unit = item['variant_unit']?.toString() ?? '';
    final packageType = item['package_type']?.toString();
    final variantLabel = qty == null
        ? unit
        : '${qty == qty.roundToDouble() ? qty.toInt() : qty} $unit${(packageType != null && packageType != 'LOOSE') ? ' $packageType' : ''}';
    final price = (item['current_price'] as num?) ?? 0;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.subheading, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (brand != null && brand.isNotEmpty) Text(brand, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(variantLabel, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text('₹${formatIndianAmount(price)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.businessName, this.onReorder});

  final Map<String, dynamic> order;
  final String businessName;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final amount = (order['total_amount'] as num?) ?? 0;
    final orderId = order['id']?.toString() ?? '';
    final orderRef = orderId.length >= 6 ? 'OM${orderId.substring(0, 6).toUpperCase()}' : 'OM${orderId.toUpperCase()}';
    final itemCount = (order['order_items'] as List<dynamic>?)?.length ?? 0;
    final createdRaw = order['created_at']?.toString();
    final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
    final dateLabel = created == null ? '' : DateFormat('d MMM yyyy').format(created);
    final paymentBadge = _paymentBadge(order);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderRef, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(businessName, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              Text('₹${formatIndianAmount(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$dateLabel${dateLabel.isEmpty ? '' : ' · '}$itemCount item${itemCount == 1 ? '' : 's'}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: paymentBadge.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(paymentBadge.icon, size: 11, color: paymentBadge.fg),
                    const SizedBox(width: 3),
                    Text(paymentBadge.label, style: TextStyle(color: paymentBadge.fg, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (onReorder != null) ...[
                const Spacer(),
                TextButton.icon(
                  onPressed: onReorder,
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Reorder'),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  _PaymentBadge _paymentBadge(Map<String, dynamic> order) {
    final method = order['payment_method']?.toString();
    final status = order['payment_status']?.toString() ?? 'pending';
    final methodLabel = switch (method) {
      'upi' => 'UPI',
      'cash_on_delivery' => 'COD',
      _ => 'Payment',
    };
    final statusLabel = status.isEmpty ? 'PENDING' : status.toUpperCase();
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

/// Merges notifications across every business the customer belongs to.
/// [NotificationService.getForCurrentUser] is business-scoped by design, so
/// this fetches it once per business (reusing the existing, proven query)
/// and combines the results client-side rather than adding a new backend
/// query or RLS policy.
class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.businesses});

  final List<CustomerBusiness> businesses;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<Map<String, dynamic>> _notifications = const <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait(
      widget.businesses.map((business) => NotificationService.getForCurrentUser(business.businessId)),
    );
    final merged = results.expand((list) => list).toList()
      ..sort((a, b) => (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
    if (!mounted) return;
    setState(() {
      _notifications = merged.take(10).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notifications', style: AppTextStyles.subheading),
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          const AppLoadingState()
        else if (_notifications.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('No notifications yet.', style: AppTextStyles.bodyMuted),
          )
        else
          ..._notifications.map((notification) {
            final isRead = notification['is_read'] == true;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isRead ? AppColors.surfaceMuted : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(notification['body']?.toString() ?? '', style: AppTextStyles.bodyMuted),
                ],
              ),
            );
          }),
      ],
    );
  }
}
