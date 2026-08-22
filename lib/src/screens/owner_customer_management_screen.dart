import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';
import '../services/owner_dashboard_service.dart';

class OwnerCustomerManagementScreen extends StatefulWidget {
  const OwnerCustomerManagementScreen({
    super.key,
    required this.businessId,
    this.onlyOutstanding = false,
    this.autoOpenAdd = false,
    this.initialName,
    this.initialPhone,
  });

  final String businessId;
  final bool onlyOutstanding;

  /// Auto-opens the Add Customer dialog, pre-filled with [initialName] /
  /// [initialPhone] -- used when the owner arrives here via the Ask
  /// Assistant ("Add Raju Stores mobile 9876543210") so they land on the
  /// normal form already filled in, still reviewing and confirming before
  /// it saves.
  final bool autoOpenAdd;
  final String? initialName;
  final String? initialPhone;

  @override
  State<OwnerCustomerManagementScreen> createState() => _OwnerCustomerManagementScreenState();
}

class _OwnerCustomerManagementScreenState extends State<OwnerCustomerManagementScreen> {
  final _customerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  bool _isLoadingCustomers = true;
  List<OwnerCustomerBalance> _customers = const <OwnerCustomerBalance>[];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAddCustomerDialog(prefillName: widget.initialName, prefillPhone: widget.initialPhone);
        }
      });
    }
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

  Future<bool> _addCustomer(bool isActive) async {
    final user = AuthService.currentUser;
    if (user == null) {
      return false;
    }

    try {
      await CustomerBusinessService.createCustomerRecord(
        businessId: widget.businessId,
        phone: _phoneController.text.trim(),
        customerName: _customerNameController.text.trim(),
        shopName: _shopNameController.text.trim(),
        address: _addressController.text.trim(),
        openingBalance: double.tryParse(_openingBalanceController.text.trim()) ?? 0,
        isActive: isActive,
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer record created')));
      _customerNameController.clear();
      _shopNameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _openingBalanceController.text = '0';
      await _loadCustomers();
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to add customer: $error')));
      return false;
    }
  }

  Future<void> _showAddCustomerDialog({String? prefillName, String? prefillPhone}) async {
    _customerNameController.text = prefillName ?? '';
    _shopNameController.clear();
    _phoneController.text = prefillPhone ?? '';
    _addressController.clear();
    _openingBalanceController.text = '0';
    bool isActive = true;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add customer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(labelText: 'Customer name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(labelText: 'Shop name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone number'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _openingBalanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Opening balance'),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      subtitle: Text(isActive ? 'Customer can place orders' : 'Customer is blocked from ordering'),
                      value: isActive,
                      onChanged: submitting ? null : (value) => setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          final success = await _addCustomer(isActive);
                          if (!dialogContext.mounted) return;
                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            setDialogState(() => submitting = false);
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    final text = (value == null || value.toString().trim().isEmpty) ? '—' : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _showCustomerDetails(OwnerCustomerBalance customer) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: CustomerBusinessService.getCustomerById(customer.customerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AlertDialog(
                content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return AlertDialog(
                title: const Text('Customer details'),
                content: const Text('Unable to load this customer.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
                ],
              );
            }

            final isRegistered = data['profile_id'] != null;
            bool isBlocked = (data['status'] as String?) == 'BLOCKED';

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(data['display_name'] as String? ?? 'Customer'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _detailRow('Shop', data['shop_name']),
                        _detailRow('Phone', data['phone']),
                        _detailRow('Address', data['address']),
                        _detailRow('Opening balance', '₹${(data['opening_balance'] as num? ?? 0).toStringAsFixed(0)}'),
                        _detailRow('Registered', isRegistered ? 'Yes' : 'Not yet'),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: Text(isBlocked ? 'Customer is blocked from ordering' : 'Customer can place orders'),
                          value: !isBlocked,
                          onChanged: (value) async {
                            await CustomerBusinessService.setCustomerBlocked(
                              customer.customerId,
                              !value,
                              isRegistered: isRegistered,
                            );
                            setDialogState(() => isBlocked = !value);
                            if (mounted) await _loadCustomers();
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
            Text(
              widget.onlyOutstanding ? 'Customers with an outstanding balance' : 'Customers in this shop',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_isLoadingCustomers)
              const Expanded(child: Center(child: CircularProgressIndicator()))
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
                        onTap: () => _showCustomerDetails(customer),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add customer'),
      ),
    );
  }
}
