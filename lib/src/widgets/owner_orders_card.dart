import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';

class OwnerOrdersCard extends StatefulWidget {
  const OwnerOrdersCard({super.key});

  @override
  State<OwnerOrdersCard> createState() => _OwnerOrdersCardState();
}

class _OwnerOrdersCardState extends State<OwnerOrdersCard> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final profile = await AuthService.getCurrentProfile();
    final businessId = profile?.businessId;

    if (businessId == null || businessId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _orders = [];
        _loading = false;
      });
      return;
    }

    final orders = await OrderService.getOrdersForBusiness(businessId);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final customer = (order['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final customerName = (customer['name'] as String?) ?? 'Customer';
    final customerPhone = (customer['phone'] as String?) ?? '';
    final items = (order['order_items'] as List<dynamic>?) ?? const <dynamic>[];
    final createdAt = OrderService.formatDisplayDate(order['created_at'] as String?);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final localized = AppLocalizations.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localized.translate('owner_order_detail_title'),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('Order #${order['id']?.toString().substring(0, 8) ?? 'n/a'}'),
              const SizedBox(height: 6),
              Text('Customer: $customerName${customerPhone.isEmpty ? '' : ' • $customerPhone'}'),
              const SizedBox(height: 6),
              Text('Placed: $createdAt'),
              const SizedBox(height: 8),
              Text('${localized.translate('owner_order_detail_status')}: ${(order['status'] as String? ?? 'pending').toUpperCase()}'),
              const SizedBox(height: 12),
              Text('Items:'),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(localized.translate('owner_order_detail_close')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    final pendingCount = _orders.where((order) => (order['status'] as String? ?? 'pending') != 'completed').length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  localized.translate('owner_orders_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Text('Loading...')
            else if (_orders.isEmpty)
              Text(localized.translate('owner_orders_empty'))
            else
              ..._orders.take(3).map((order) {
                final status = ((order['status'] as String?) ?? 'pending').toUpperCase();
                final customer = (order['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                final customerName = (customer['name'] as String?) ?? 'Customer';
                final createdAt = OrderService.formatDisplayDate(order['created_at'] as String?);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () => _showOrderDetails(context, order),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order ${order['id']?.toString().substring(0, 8) ?? 'n/a'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('From: $customerName'),
                          const SizedBox(height: 2),
                          Text('Placed: $createdAt'),
                          const SizedBox(height: 4),
                          Text('₹${(order['total_amount'] as num? ?? 0).toStringAsFixed(0)}'),
                          const SizedBox(height: 6),
                          Chip(label: Text(status)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
