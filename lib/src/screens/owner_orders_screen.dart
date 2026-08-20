import 'package:flutter/material.dart';
import '../services/order_service.dart';

class OwnerOrdersScreen extends StatefulWidget {
  const OwnerOrdersScreen({super.key, required this.businessId, this.todayOnly = false});

  final String businessId;
  final bool todayOnly;

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todayOnly ? "Today's Orders" : 'Orders'),
        actions: [
          IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Text(widget.todayOnly ? 'No orders placed today yet.' : 'No orders yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (_, index) {
                    final order = _orders[index];
                    final customer = (order['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                    final customerName = (customer['name'] as String?) ?? 'Customer';
                    final createdAt = OrderService.formatDisplayDate(order['created_at'] as String?);
                    final status = ((order['status'] as String?) ?? 'pending').toUpperCase();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text('From: $customerName'),
                        subtitle: Text('$createdAt • ₹${(order['total_amount'] as num? ?? 0).toStringAsFixed(0)}'),
                        trailing: Chip(label: Text(status), visualDensity: VisualDensity.compact),
                        onTap: () => _showOrderDetails(order),
                      ),
                    );
                  },
                ),
    );
  }
}
