import 'package:flutter/material.dart';
import '../src/localization/app_localizations.dart';
import '../src/screens/login_screen.dart';
import '../src/screens/owner_coming_soon_screen.dart';
import '../src/screens/owner_customer_management_screen.dart';
import '../src/screens/owner_invoices_screen.dart';
import '../src/screens/owner_orders_screen.dart';
import '../src/screens/owner_product_management_screen.dart';
import '../src/screens/owner_transactions_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_business_service.dart';
import '../src/services/owner_dashboard_service.dart';
import '../src/widgets/owner_orders_card.dart';
import '../src/widgets/voice_order_card.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final GlobalKey _voiceOrderKey = GlobalKey();

  String? _ownerName;
  OwnerDashboardSummary _summary = OwnerDashboardSummary.empty;
  List<Map<String, dynamic>> _productPreview = const <Map<String, dynamic>>[];
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
      final products = summary.businessId.isEmpty
          ? const <Map<String, dynamic>>[]
          : await CustomerBusinessService.getProductsForBusiness(summary.businessId);

      if (!mounted) return;
      setState(() {
        _ownerName = profile?.name;
        _summary = summary;
        _productPreview = products.take(3).toList();
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

  void _scrollToVoiceOrder() {
    final voiceContext = _voiceOrderKey.currentContext;
    if (voiceContext != null) {
      Scrollable.ensureVisible(voiceContext, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    final businessId = _summary.businessId;
    final hasBusiness = businessId.isNotEmpty && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(localized.translate('owner_home_title')),
        actions: [
          IconButton(onPressed: _loadDashboard, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Logout'),
        ],
      ),
      drawer: _OwnerNavDrawer(
        businessId: businessId,
        onNavigate: (screen) {
          Navigator.pop(context);
          if (screen != null) _push(screen);
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Welcome, ${_ownerName?.isNotEmpty == true ? _ownerName : 'Owner'}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _isLoading
                    ? 'Loading your shop...'
                    : (_summary.businessName.isEmpty ? 'Business ready for orders.' : 'Managing: ${_summary.businessName}'),
                style: const TextStyle(color: Colors.black54),
              ),
              if (_loadError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text('Unable to load dashboard: $_loadError', style: TextStyle(color: Colors.red.shade900)),
                ),
              ],
              const SizedBox(height: 20),
              _SummaryGrid(
                summary: _summary,
                onTotalCustomers: () => _push(OwnerCustomerManagementScreen(businessId: businessId)),
                onTodayOrders: () => _push(OwnerOrdersScreen(businessId: businessId, todayOnly: true)),
                onTodayRevenue: () => _push(OwnerTransactionsScreen(businessId: businessId, todayOnly: true)),
                onPendingAmount: () => _push(OwnerCustomerManagementScreen(businessId: businessId, onlyOutstanding: true)),
              ),
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _QuickActionsGrid(
                enabled: hasBusiness,
                onAddCustomer: () => _push(OwnerCustomerManagementScreen(businessId: businessId)),
                onAddProduct: () => _push(OwnerProductManagementScreen(businessId: businessId, autoOpenAdd: true)),
                onNewOrder: _scrollToVoiceOrder,
                onViewInvoices: () => _push(OwnerInvoicesScreen(businessId: businessId)),
              ),
              const SizedBox(height: 24),
              const Text("Today's Orders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const OwnerOrdersCard(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton(
                    onPressed: hasBusiness ? () => _push(OwnerProductManagementScreen(businessId: businessId)) : null,
                    child: const Text('View All Products'),
                  ),
                ],
              ),
              if (_productPreview.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No products added yet.', style: TextStyle(color: Colors.black54)),
                )
              else
                ..._productPreview.map((product) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(product['name']?.toString() ?? 'Product'),
                        subtitle: Text(
                          '${product['unit']?.toString() ?? 'unit'} • ₹${(product['price'] as num? ?? 0).toStringAsFixed(0)}',
                        ),
                      ),
                    )),
              const SizedBox(height: 24),
              KeyedSubtree(key: _voiceOrderKey, child: const VoiceOrderCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.onTotalCustomers,
    required this.onTodayOrders,
    required this.onTodayRevenue,
    required this.onPendingAmount,
  });

  final OwnerDashboardSummary summary;
  final VoidCallback onTotalCustomers;
  final VoidCallback onTodayOrders;
  final VoidCallback onTodayRevenue;
  final VoidCallback onPendingAmount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricConfig(label: 'Total Customers', value: summary.totalCustomers.toString(), icon: Icons.groups_2, color: Colors.indigo, onTap: onTotalCustomers),
      _MetricConfig(label: "Today's Orders", value: summary.todayOrders.toString(), icon: Icons.receipt_long, color: Colors.teal, onTap: onTodayOrders),
      _MetricConfig(label: "Today's Revenue", value: '₹${summary.todayRevenue.toStringAsFixed(0)}', icon: Icons.trending_up, color: Colors.green, onTap: onTodayRevenue),
      _MetricConfig(label: 'Pending Amount', value: '₹${summary.pendingAmount.toStringAsFixed(0)}', icon: Icons.hourglass_bottom, color: Colors.orange, onTap: onPendingAmount),
    ];

    return GridView.builder(
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 2 : 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.55,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: metric.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: metric.color.withValues(alpha: 0.12), child: Icon(metric.icon, color: metric.color)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metric.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(metric.label, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricConfig {
  const _MetricConfig({required this.label, required this.value, required this.icon, required this.color, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.enabled,
    required this.onAddCustomer,
    required this.onAddProduct,
    required this.onNewOrder,
    required this.onViewInvoices,
  });

  final bool enabled;
  final VoidCallback onAddCustomer;
  final VoidCallback onAddProduct;
  final VoidCallback onNewOrder;
  final VoidCallback onViewInvoices;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (label: 'Add Customer', icon: Icons.person_add_alt_1, onTap: onAddCustomer),
      (label: 'Add Product', icon: Icons.add_box_outlined, onTap: onAddProduct),
      (label: 'New Order', icon: Icons.mic, onTap: onNewOrder),
      (label: 'View Invoices', icon: Icons.receipt_outlined, onTap: onViewInvoices),
    ];

    return GridView.builder(
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final action = actions[index];
        return OutlinedButton.icon(
          onPressed: enabled ? action.onTap : null,
          icon: Icon(action.icon, size: 18),
          label: Text(action.label, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

class _OwnerNavDrawer extends StatelessWidget {
  const _OwnerNavDrawer({required this.businessId, required this.onNavigate});

  final String businessId;
  final void Function(Widget? screen) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Owner Menu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
            ListTile(leading: const Icon(Icons.dashboard_outlined), title: const Text('Dashboard'), onTap: () => onNavigate(null)),
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: const Text('Customers'),
              onTap: () => onNavigate(OwnerCustomerManagementScreen(businessId: businessId)),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Products'),
              onTap: () => onNavigate(OwnerProductManagementScreen(businessId: businessId)),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Orders'),
              onTap: () => onNavigate(OwnerOrdersScreen(businessId: businessId)),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Invoices'),
              onTap: () => onNavigate(OwnerInvoicesScreen(businessId: businessId)),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_outlined),
              title: const Text('Transactions'),
              onTap: () => onNavigate(OwnerTransactionsScreen(businessId: businessId)),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Reports'),
              onTap: () => onNavigate(const OwnerComingSoonScreen(title: 'Reports')),
            ),
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Price Management'),
              onTap: () => onNavigate(const OwnerComingSoonScreen(title: 'Price Management')),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile/Settings'),
              onTap: () => onNavigate(const OwnerComingSoonScreen(title: 'Profile/Settings')),
            ),
          ],
        ),
      ),
    );
  }
}
