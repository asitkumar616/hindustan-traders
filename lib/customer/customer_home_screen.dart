import 'package:flutter/material.dart';
import '../src/localization/app_localizations.dart';
import '../src/screens/login_screen.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_business_service.dart';
import '../src/widgets/draft_history_card.dart';
import '../src/widgets/notifications_card.dart';
import '../src/widgets/product_catalog_card.dart';
import '../src/widgets/voice_order_card.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.businessId, required this.businessName});

  final String businessId;
  final String businessName;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingCatalog = true;

  @override
  void initState() {
    super.initState();
    refreshCatalog();
  }

  Future<void> refreshCatalog() async {
    setState(() => _isLoadingCatalog = true);
    final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoadingCatalog = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.businessName),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localized.translate('customer_home_message'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text('Shopping at: ${widget.businessName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              NotificationsCard(businessId: widget.businessId),
              const SizedBox(height: 20),
              ProductCatalogCard(
                businessName: widget.businessName,
                products: _products,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoadingCatalog ? null : refreshCatalog,
                  child: const Text('Refresh catalog'),
                ),
              ),
              const SizedBox(height: 20),
              const DraftHistoryCard(),
              const SizedBox(height: 20),
              VoiceOrderCard(businessId: widget.businessId),
            ],
          ),
        ),
      ),
    );
  }
}
