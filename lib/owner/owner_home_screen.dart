import 'package:flutter/material.dart';
import '../src/localization/app_localizations.dart';
import '../src/screens/owner_customer_management_screen.dart';
import '../src/screens/owner_invoices_screen.dart';
import '../src/screens/owner_product_management_screen.dart';
import '../src/services/auth_service.dart';
import '../src/widgets/outstanding_invoices_card.dart';
import '../src/widgets/owner_orders_card.dart';
import '../src/widgets/voice_order_card.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  String? _businessId;
  String? _businessName;
  bool _isLoadingBusiness = true;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final profile = await AuthService.getCurrentProfile();
    if (mounted) {
      setState(() {
        _businessId = profile?.businessId;
        _businessName = profile?.name;
        _isLoadingBusiness = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localized.translate('owner_home_title'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localized.translate('owner_home_message'),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              if (_isLoadingBusiness)
                const Text('Loading your shop...')
              else
                Text(
                  _businessName == null || _businessName!.isEmpty
                      ? 'Business ready for orders.'
                      : 'Managing: $_businessName',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _businessId == null || _isLoadingBusiness
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OwnerCustomerManagementScreen(businessId: _businessId!),
                            ),
                          );
                        },
                  child: _isLoadingBusiness
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Manage customers'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _businessId == null || _isLoadingBusiness
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OwnerProductManagementScreen(businessId: _businessId!),
                            ),
                          );
                        },
                  child: const Text('Manage products'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _businessId == null || _isLoadingBusiness
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OwnerInvoicesScreen(businessId: _businessId!),
                            ),
                          );
                        },
                  child: const Text('View invoices'),
                ),
              ),
              const SizedBox(height: 20),
              if (_businessId != null && !_isLoadingBusiness)
                OutstandingInvoicesCard(businessId: _businessId!),
              const SizedBox(height: 20),
              const OwnerOrdersCard(),
              const SizedBox(height: 20),
              const VoiceOrderCard(),
            ],
          ),
        ),
      ),
    );
  }
}
