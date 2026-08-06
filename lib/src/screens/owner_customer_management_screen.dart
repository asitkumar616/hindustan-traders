import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';

class OwnerCustomerManagementScreen extends StatefulWidget {
  const OwnerCustomerManagementScreen({super.key, required this.businessId});

  final String businessId;

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
  List<Map<String, dynamic>> _customers = [];

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
      final customers = await CustomerBusinessService.getCustomersForBusiness(widget.businessId);
      if (mounted) {
        setState(() => _customers = customers);
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
      appBar: AppBar(title: const Text('Customers')),
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
            const Text('Customers in this shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_isLoadingCustomers)
              const Center(child: CircularProgressIndicator())
            else if (_customers.isEmpty)
              const Text('No customers linked yet.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (_, index) {
                    final customer = _customers[index];
                    final displayName = customer['display_name']?.toString() ?? 'Customer';
                    final shopName = customer['shop_name']?.toString() ?? '—';
                    final phone = customer['phone']?.toString() ?? '—';
                    return ListTile(
                      title: Text(displayName),
                      subtitle: Text('$shopName • $phone'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
