import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class ProductCatalogCard extends StatelessWidget {
  const ProductCatalogCard({super.key, this.businessName, this.products = const []});

  final String? businessName;
  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context);
    final displayProducts = products.isEmpty
        ? [
            {'name': 'Rice', 'unit': 'kg', 'price': 55.0},
            {'name': 'Dal', 'unit': 'kg', 'price': 100.0},
            {'name': 'Salt', 'unit': 'packet', 'price': 25.0},
          ]
        : products;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localized.translate('catalog_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              businessName == null
                  ? localized.translate('catalog_message')
                  : 'Catalogue for $businessName',
            ),
            const SizedBox(height: 12),
            ...displayProducts.map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${product['name']} (${product['unit']})'),
                      ),
                      Text('₹${(product['price'] as num).toStringAsFixed(0)}'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
