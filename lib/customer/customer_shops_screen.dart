import 'package:flutter/material.dart';
import '../src/screens/login_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_dashboard_service.dart';
import '../src/services/notification_service.dart';
import '../src/services/order_service.dart';
import '../src/theme/app_colors.dart';
import '../src/theme/app_radius.dart';
import '../src/theme/app_spacing.dart';
import '../src/theme/app_text_styles.dart';
import '../src/utils/formatters.dart';
import '../src/widgets/app_card.dart';
import '../src/widgets/app_empty_state.dart';
import '../src/widgets/app_error_state.dart';
import '../src/widgets/app_loading_state.dart';
import '../src/widgets/app_secondary_button.dart';
import '../src/widgets/app_section_header.dart';
import '../src/widgets/app_voice_bottom_nav.dart';
import '../src/widgets/voice_order_card.dart';
import 'customer_home_screen.dart';
import 'customer_orders_screen.dart';

class CustomerShopsScreen extends StatefulWidget {
  const CustomerShopsScreen({super.key});

  @override
  State<CustomerShopsScreen> createState() => _CustomerShopsScreenState();
}

class _CustomerShopsScreenState extends State<CustomerShopsScreen> {
  String? _customerName;
  List<CustomerBusiness> _businesses = const <CustomerBusiness>[];
  List<Map<String, dynamic>> _recentOrders = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _loadError;

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
      final recentOrders = await OrderService.getRecentOrdersForCustomer(limit: 3);
      if (!mounted) return;
      setState(() {
        _customerName = profile?.name;
        _businesses = businesses;
        _recentOrders = recentOrders;
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

  void _openShop(CustomerBusiness business) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerHomeScreen(businessId: business.businessId, businessName: business.businessName),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _requestNewShop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requesting a new shop is coming soon. Ask the shop owner to add your number for now.')),
    );
  }

  void _openOrders() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()));
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
    _pickShopForVoice();
  }

  void _pickShopForVoice() {
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
              const Text('Choose a shop to speak your order', style: AppTextStyles.subheading),
              const SizedBox(height: AppSpacing.md),
              ..._businesses.map(
                (business) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                  title: Text(business.businessName),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openVoiceSheet(business);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  void _showNotifications() {
    if (_businesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notifications yet.')));
      return;
    }
    showModalBottomSheet<void>(
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

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _showNotifications,
                  icon: const Icon(Icons.notifications_none_rounded),
                  color: AppColors.textPrimary,
                ),
              ),
              Text('Hello, $greetingName \u{1F44B}', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              const Text('What do you need today?', style: AppTextStyles.bodyMuted),
              if (_loadError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  message: 'Something went wrong. Unable to load your shops.',
                  onRetry: _load,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SpeakOrderButton(onTap: _startVoiceOrder),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'My Shops'),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const AppLoadingState()
              else if (_businesses.isEmpty && _loadError == null)
                const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No Shops Yet',
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
              AppSecondaryButton(
                label: 'Add / Request New Shop',
                icon: Icons.add,
                onPressed: _requestNewShop,
              ),
              if (!_loading && _recentOrders.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                AppSectionHeader(title: 'Recent Orders', actionLabel: 'View All', onAction: _openOrders),
                const SizedBox(height: AppSpacing.md),
                ..._recentOrders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _RecentOrderCard(order: order, businesses: _businesses),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.primary,
        accentLight: AppColors.primaryLight,
        leftItems: const [
          AppNavItem(icon: Icons.home_rounded, label: 'Home', active: true),
          AppNavItem(icon: Icons.storefront_outlined, label: 'My Shops'),
        ],
        rightItems: [
          AppNavItem(icon: Icons.receipt_long_outlined, label: 'Orders', onTap: _openOrders),
          AppNavItem(icon: Icons.person_outline_rounded, label: 'Profile', onTap: _logout),
        ],
        onVoice: _startVoiceOrder,
      ),
    );
  }
}

class _SpeakOrderButton extends StatelessWidget {
  const _SpeakOrderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Speak Order', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text(
              'Odia • Hindi • English',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.businesses});

  final Map<String, dynamic> order;
  final List<CustomerBusiness> businesses;

  @override
  Widget build(BuildContext context) {
    final businessId = order['business_id']?.toString() ?? '';
    final matches = businesses.where((business) => business.businessId == businessId);
    final businessName = matches.isNotEmpty ? matches.first.businessName : 'Shop';
    final amount = (order['total_amount'] as num?) ?? 0;
    final status = (order['status'] as String?) ?? 'pending';
    final placedAt = OrderService.formatDisplayDate(order['created_at'] as String?);
    final statusStyle = _statusStyleFor(status);

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(businessName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(placedAt, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
