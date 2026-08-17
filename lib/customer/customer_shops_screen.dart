import 'package:flutter/material.dart';
import '../src/screens/login_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_dashboard_service.dart';
import 'customer_home_screen.dart';

class CustomerShopsScreen extends StatefulWidget {
  const CustomerShopsScreen({super.key});

  @override
  State<CustomerShopsScreen> createState() => _CustomerShopsScreenState();
}

class _CustomerShopsScreenState extends State<CustomerShopsScreen> {
  String? _customerName;
  List<CustomerBusiness> _businesses = const <CustomerBusiness>[];
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
      if (!mounted) return;
      setState(() {
        _customerName = profile?.name;
        _businesses = businesses;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shops'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Logout'),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Welcome ${_customerName?.isNotEmpty == true ? _customerName : ''} 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('MY SHOPS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
              const SizedBox(height: 16),
              if (_loadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text('Unable to load your shops: $_loadError', style: TextStyle(color: Colors.red.shade900)),
                ),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_businesses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'You are not linked to any shop yet. Ask a shop owner to add your mobile number as a customer.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ..._businesses.map((business) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text('🏪', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(business.businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  if (business.customerDisplayName?.isNotEmpty == true)
                                    Text(business.customerDisplayName!, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _openShop(business),
                              child: const Text('Shop / Order'),
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _requestNewShop,
                icon: const Icon(Icons.add),
                label: const Text('Add / Request New Shop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
