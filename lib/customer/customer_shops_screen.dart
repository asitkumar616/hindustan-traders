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
import '../src/utils/product_images.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_error_state.dart';
import '../src/widgets/app_loading_state.dart';
import '../src/widgets/app_voice_bottom_nav.dart' show AppNavItem;
import '../src/widgets/dashboard_bottom_nav.dart';
import '../src/widgets/dashboard_quick_action_tile.dart';
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
  /// one business before it can proceed (Shop Products, a category tap, an
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

  /// Bottom-nav "More" entry point -- keeps Voice Order and Profile/Logout
  /// reachable without putting a floating mic over this dashboard's
  /// approved layout.
  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.mic_rounded, color: AppColors.primary),
                title: const Text('Voice Order'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startVoiceOrder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openProfile();
                },
              ),
            ],
          ),
        ),
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
            children: [
              _DashboardHeader(
                businessIds: _businesses.map((b) => b.businessId).toList(),
                onNotificationsTap: _showNotifications,
              ),
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  message: 'Something went wrong. Unable to load your dashboard.',
                  onRetry: _load,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _GreetingCard(greeting: _greeting, name: greetingName),
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
              const SizedBox(height: AppSpacing.lg),
              const Text('Quick Actions', style: AppTextStyles.subheading),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.storefront_outlined,
                      label: 'Shop Products',
                      accentColor: AppColors.categoryDal,
                      onTap: _startShopping,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'My Orders',
                      accentColor: AppColors.danger,
                      onTap: _openOrders,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.payments_outlined,
                      label: 'Payments',
                      accentColor: AppColors.info,
                      onTap: _openOrders,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DashboardQuickActionTile(
                      icon: Icons.description_outlined,
                      label: 'Invoices',
                      accentColor: AppColors.success,
                      onTap: _openOrders,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _DailyEssentialsBanner(onTap: _startShopping),
              const SizedBox(height: AppSpacing.lg),
              KeyedSubtree(
                key: _shopsSectionKey,
                child: _SectionHeader(title: 'Connected Shops', actionLabel: _businesses.isEmpty ? null : 'View All', onAction: _scrollToShops),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_loading)
                const AppLoadingState()
              else if (_businesses.isEmpty && _loadError == null)
                const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No Shops Connected Yet',
                  message: 'Ask a shop owner to add your mobile number as a customer to get started.',
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _businesses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) => _ConnectedShopCard(
                      business: _businesses[index],
                      onTap: () => _openShop(_businesses[index]),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _requestNewShop,
                icon: const Icon(Icons.add),
                label: const Text('Add / Request New Shop'),
              ),
              if (!_loading) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(title: 'Recent Orders', actionLabel: recentOrders.isEmpty ? null : 'View All', onAction: _openOrders),
                const SizedBox(height: AppSpacing.sm),
                if (recentOrders.isEmpty)
                  const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Orders Yet',
                    message: 'Start shopping to place your first order.',
                  )
                else
                  ...recentOrders.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RecentOrderCard(
                        order: entry.value,
                        avatarIndex: entry.key,
                        businessName: _businessById(entry.value['business_id']?.toString() ?? '')?.businessName ?? 'Shop',
                        onTap: entry.value['status'] == 'completed' ? () => _reorder(entry.value) : _openOrders,
                      ),
                    ),
                  ),
              ],
              if (!_loading && _categories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(title: 'Shop by Category'),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(title: 'Frequently Ordered'),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 190,
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
              const SizedBox(height: AppSpacing.lg),
              _ExploreShopsBanner(onTap: _requestNewShop),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        items: [
          const AppNavItem(icon: Icons.home_rounded, label: 'Home', active: true),
          AppNavItem(icon: Icons.storefront_outlined, label: 'Shops', onTap: _scrollToShops),
          AppNavItem(icon: Icons.receipt_long_outlined, label: 'Orders', onTap: _openOrders),
          AppNavItem(icon: Icons.shopping_cart_outlined, label: 'Cart', onTap: _startShopping),
          AppNavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: _showMoreMenu),
        ],
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

/// Header row: brand mark + tagline on the left, notification bell on the
/// right. Deliberately no hamburger/business-selector/profile info here --
/// this dashboard has no single "current business" the way the Owner
/// dashboard does, and the approved mockup keeps this header minimal.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.businessIds, required this.onNotificationsTap});

  final List<String> businessIds;
  final Future<void> Function() onNotificationsTap;

  @override
  Widget build(BuildContext context) {
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
        NotificationBell(businessIds: businessIds, onTap: onNotificationsTap),
      ],
    );
  }
}

/// Compact cream greeting banner, matching the Owner dashboard's treatment
/// instead of a large saturated gradient.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.greeting, required this.name});

  final String greeting;
  final String name;

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
                Text('$greeting,', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(
                  '$name!',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Fresh products. Better prices. Always.',
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
            child: const Icon(Icons.shopping_basket_rounded, color: AppColors.primary, size: 24),
          ),
        ],
      ),
    );
  }
}

/// Plain section-header row -- title in the same subheading style used
/// throughout the Owner dashboard, with an optional "View All" action.
/// Deliberately not [AppSectionHeader] (which renders small-caps labels);
/// the approved mockup uses normal-case bold headings here.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.subheading),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
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

    final items = [
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
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.7,
      children: items,
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
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.15),
                  maxLines: 2,
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
        'No change · vs last month',
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
            '${percent.abs()}% vs last month',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Cream promo banner driving the customer into the shopping flow --
/// visually matches the greeting card's quieter palette rather than a
/// saturated gradient.
class _DailyEssentialsBanner extends StatelessWidget {
  const _DailyEssentialsBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                const Text(
                  'Best Prices on Daily Essentials',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Rice, Dal, Oil, Atta and more from your trusted shops',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Shop Now'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_basket_rounded, color: AppColors.primary, size: 24),
          ),
        ],
      ),
    );
  }
}

/// Light-lavender banner nudging the customer to connect more shops --
/// visually distinct from the cream Daily Essentials banner above it.
class _ExploreShopsBanner extends StatelessWidget {
  const _ExploreShopsBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.categoryDal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore More Shops',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Get connected with more trusted wholesale shops.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.categoryDal, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal shop card. Only a name and a placeholder storefront icon are
/// shown -- the backend has no shop photo or rating field yet, so neither
/// is fabricated here.
class _ConnectedShopCard extends StatelessWidget {
  const _ConnectedShopCard({required this.business, required this.onTap});

  final CustomerBusiness business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                business.businessName,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
    final visual = categoryVisual(null);
    final imageAsset = productImageAsset(productName: name);

    return Container(
      width: 136,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: imageAsset == null
                ? Container(
                    width: double.infinity,
                    height: 72,
                    color: visual.color.withValues(alpha: 0.1),
                    child: Icon(visual.icon, color: visual.color, size: 30),
                  )
                : Image.asset(
                    imageAsset,
                    width: double.infinity,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 72,
                      color: visual.color.withValues(alpha: 0.1),
                      child: Icon(visual.icon, color: visual.color, size: 30),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (brand != null && brand.isNotEmpty)
            Text(brand, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(variantLabel, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('₹${formatIndianAmount(price)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.shopping_cart_rounded, size: 15, color: AppColors.primary),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.avatarIndex, required this.businessName, required this.onTap});

  final Map<String, dynamic> order;
  final int avatarIndex;
  final String businessName;
  final VoidCallback onTap;

  static const _avatarColors = [AppColors.info, AppColors.success, AppColors.primary, AppColors.categoryDal];

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
            child: Icon(Icons.receipt_long_rounded, color: avatarColor, size: 17),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderRef, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(businessName, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                  '$dateLabel${dateLabel.isEmpty ? '' : ' · '}$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
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
