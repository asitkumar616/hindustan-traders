import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';

class AdminBusinessListScreen extends StatefulWidget {
  const AdminBusinessListScreen({super.key});

  @override
  State<AdminBusinessListScreen> createState() => _AdminBusinessListScreenState();
}

class _AdminBusinessListScreenState extends State<AdminBusinessListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _query = '';
  List<AdminBusinessRecord> _businesses = const <AdminBusinessRecord>[];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _loading = true);
    try {
      final businesses = await AdminDashboardService.listBusinesses(query: _query.isEmpty ? null : _query);
      if (!mounted) return;
      setState(() => _businesses = businesses);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load businesses: $error')),
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
        title: const Text('Businesses'),
        actions: [
          IconButton(onPressed: _loadBusinesses, icon: const Icon(Icons.refresh)),
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
                _loadBusinesses();
              },
              decoration: InputDecoration(
                hintText: 'Search businesses by name, owner, or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                    _loadBusinesses();
                  },
                  icon: const Icon(Icons.clear),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _businesses.isEmpty
                      ? const Center(child: Text('No businesses found.'))
                      : ListView.builder(
                          itemCount: _businesses.length,
                          itemBuilder: (context, index) {
                            final business = _businesses[index];
                            final statusColor = business.businessStatus == 'active' ? Colors.green : Colors.grey;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(alpha: 0.15),
                                  child: Icon(Icons.store_mall_directory, color: statusColor),
                                ),
                                title: Text(business.businessName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${business.ownerName} • ${business.ownerPhone}\n'
                                  '${business.businessAddress?.isNotEmpty == true ? '${business.businessAddress}\n' : ''}'
                                  'Status: ${business.businessStatus.toUpperCase()} • Customers: ${business.customerCount}',
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
