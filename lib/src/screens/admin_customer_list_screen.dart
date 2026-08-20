import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';

class AdminCustomerListScreen extends StatefulWidget {
  const AdminCustomerListScreen({super.key, required this.onlyActive});

  final bool onlyActive;

  @override
  State<AdminCustomerListScreen> createState() => _AdminCustomerListScreenState();
}

class _AdminCustomerListScreenState extends State<AdminCustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _query = '';
  List<AdminCustomerRecord> _customers = const <AdminCustomerRecord>[];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    try {
      final customers = await AdminDashboardService.listCustomers(
        query: _query.isEmpty ? null : _query,
        activeOnly: widget.onlyActive,
      );
      if (!mounted) return;
      setState(() => _customers = customers);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load customers: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onlyActive ? 'Active Customers' : 'All Customers'),
        actions: [
          IconButton(onPressed: _loadCustomers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (value) {
                setState(() => _query = value.trim());
                _loadCustomers();
              },
              decoration: InputDecoration(
                hintText: 'Search customers by name, shop, phone, or business',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                    _loadCustomers();
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? Center(child: Text(widget.onlyActive ? 'No active customers found.' : 'No customers found.'))
                      : ListView.builder(
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            final statusColor = customer.isActive ? Colors.green : Colors.grey;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(alpha: 0.15),
                                  child: Icon(Icons.person, color: statusColor),
                                ),
                                title: Text(customer.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${customer.phone?.isNotEmpty == true ? customer.phone : 'No phone'}\n'
                                  '${customer.businessName}\n'
                                  'Status: ${customer.status} • ${customer.isActive ? 'ACTIVE' : 'INACTIVE'}',
                                ),
                                isThreeLine: true,
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
