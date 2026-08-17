import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';
import '../services/owner_dashboard_service.dart';

class OwnerCustomerManagementScreen extends StatefulWidget {
  const OwnerCustomerManagementScreen({super.key, required this.businessId, this.onlyOutstanding = false});

  final String businessId;
  final bool onlyOutstanding;

  @override
  State<OwnerCustomerManagementScreen> createState() => _OwnerCustomerManagementScreenState();
}

class _OwnerCustomerManagementScreenState extends State<OwnerCustomerManagementScreen> {
  final _customerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  bool _isSubmitting = false;
  bool _isLoadingCustomers = true;
  List<OwnerCustomerBalance> _customers = const <OwnerCustomerBalance>[];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final customers = await OwnerDashboardService.fetchCustomerBalances(onlyOutstanding: widget.onlyOutstanding);
      if (mounted) {
        setState(() => _customers = customers);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load customers: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
    }
  }

  Future<void> _addCustomer() async {
    final user = AuthService.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CustomerBusinessService.createCustomerRecord(
        businessId: widget.businessId,
        phone: _phoneController.text.trim(),
        customerName: _customerNameController.text.trim(),
        shopName: _shopNameController.text.trim(),
        address: _addressController.text.trim(),
        openingBalance: double.tryParse(_openingBalanceController.text.trim()) ?? 0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer record created')));
      _customerNameController.clear();
      _shopNameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _openingBalanceController.text = '0';
      await _loadCustomers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to add customer: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onlyOutstanding ? 'Outstanding Customers' : 'Customers'),
        actions: [
          IconButton(onPressed: _loadCustomers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a customer to this shop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(labelText: 'Customer name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopNameController,
              decoration: const InputDecoration(labelText: 'Shop name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Opening balance', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _addCustomer,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Link customer'),
            ),
            const SizedBox(height: 24),
            Text(
              widget.onlyOutstanding ? 'Customers with an outstanding balance' : 'Customers in this shop',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_isLoadingCustomers)
              const Center(child: CircularProgressIndicator())
            else if (_customers.isEmpty)
              Text(widget.onlyOutstanding ? 'No customers with an outstanding balance.' : 'No customers linked yet.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (_, index) {
                    final customer = _customers[index];
                    final lastOrder = customer.lastOrderAt;
                    final lastOrderText = lastOrder == null
                        ? 'No orders yet'
                        : 'Last order: ${lastOrder.toLocal().day.toString().padLeft(2, '0')}/'
                            '${lastOrder.toLocal().month.toString().padLeft(2, '0')}/${lastOrder.toLocal().year}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(customer.displayName),
                        subtitle: Text('${customer.phone ?? '—'}\n$lastOrderText'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${customer.outstandingAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: customer.outstandingAmount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                            const Text('outstanding', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
