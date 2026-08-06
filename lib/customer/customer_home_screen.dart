import 'package:flutter/material.dart';
import '../src/localization/app_localizations.dart';
import '../src/services/auth_service.dart';
import '../src/services/customer_business_service.dart';
import '../src/widgets/draft_history_card.dart';
import '../src/widgets/product_catalog_card.dart';
import '../src/widgets/voice_order_card.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String? _businessName;
  String? _businessId;
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingBusiness = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessContext();
  }

  Future<void> _loadBusinessContext() async {
    final profile = await AuthService.getCurrentProfile();
    if (!mounted) return;

    if (profile?.businessId != null) {
      final products = await CustomerBusinessService.getProductsForBusiness(profile!.businessId!);
      if (mounted) {
        setState(() {
          _businessName = profile.name ?? 'Your shop';
          _businessId = profile.businessId;
          _products = products;
          _isLoadingBusiness = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _businessName = profile?.name ?? 'Your shop';
        _businessId = profile?.businessId;
        _isLoadingBusiness = false;
      });
    }
  }

  Future<void> refreshCatalog() async {
    setState(() => _isLoadingBusiness = true);
    await _loadBusinessContext();
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localized.translate('customer_home_title'))),
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
                      if (_isLoadingBusiness)
                        const Text('Loading your linked shop...')
                      else
                        Text(
                          _businessName == null || _businessName!.isEmpty
                              ? 'Your shop connection is ready.'
                              : 'Connected to $_businessName',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ProductCatalogCard(
                businessName: _businessName,
                products: _products,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoadingBusiness ? null : refreshCatalog,
                  child: const Text('Refresh catalog'),
                ),
              ),
              const SizedBox(height: 20),
              const DraftHistoryCard(),
              const SizedBox(height: 20),
              const VoiceOrderCard(),
            ],
          ),
        ),
      ),
    );
  }
}
