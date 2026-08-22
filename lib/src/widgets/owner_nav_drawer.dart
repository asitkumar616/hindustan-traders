import 'package:flutter/material.dart';
import '../screens/owner_coming_soon_screen.dart';
import '../screens/owner_customer_management_screen.dart';
import '../screens/owner_invoices_screen.dart';
import '../screens/owner_orders_screen.dart';
import '../screens/owner_product_management_screen.dart';
import '../screens/owner_reports_screen.dart';
import '../screens/owner_transactions_screen.dart';

/// Shared "More" drawer for every Owner-app screen (Dashboard, Products,
/// Orders, ...), so each screen doesn't need its own copy of the same menu.
class OwnerNavDrawer extends StatelessWidget {
  const OwnerNavDrawer({
    super.key,
    required this.businessId,
    required this.onDashboard,
    required this.onNavigate,
    required this.onLogout,
  });

  final String businessId;
  final VoidCallback onDashboard;
  final void Function(Widget screen) onNavigate;
  final VoidCallback onLogout;

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
            ListTile(leading: const Icon(Icons.dashboard_outlined), title: const Text('Dashboard'), onTap: onDashboard),
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
              onTap: () => onNavigate(OwnerReportsScreen(businessId: businessId)),
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
