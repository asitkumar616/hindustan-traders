import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';

class OwnerProductManagementScreen extends StatefulWidget {
  const OwnerProductManagementScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerProductManagementScreen> createState() => _OwnerProductManagementScreenState();
}

class _OwnerProductManagementScreenState extends State<OwnerProductManagementScreen> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController(text: 'kg');
  final _priceController = TextEditingController(text: '0');
  bool _isSubmitting = false;
  bool _isLoadingProducts = true;
  String? _editingProductId;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId);
      if (mounted) {
        setState(() => _products = products);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  void _resetForm() {
    _editingProductId = null;
    _nameController.clear();
    _unitController.text = 'kg';
    _priceController.text = '0';
  }

  Future<void> _saveProduct() async {
    final user = AuthService.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_editingProductId != null) {
        await CustomerBusinessService.updateProduct(
          productId: _editingProductId!,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim(),
          price: double.tryParse(_priceController.text.trim()),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
      } else {
        await CustomerBusinessService.createProduct(
          businessId: widget.businessId,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim(),
          price: double.tryParse(_priceController.text.trim()) ?? 0,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added')));
      }

      _resetForm();
      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save product: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _startEditing(Map<String, dynamic> product) {
    _editingProductId = product['id']?.toString();
    _nameController.text = product['name']?.toString() ?? '';
    _unitController.text = product['unit']?.toString() ?? 'kg';
    _priceController.text = (product['price'] as num? ?? 0).toString();
  }

  Future<void> _deleteProduct(String productId) async {
    setState(() => _isSubmitting = true);
    try {
      await CustomerBusinessService.deleteProduct(productId: productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product removed')));
      _resetForm();
      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to remove product: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a product to this shop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _saveProduct,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_editingProductId == null ? 'Save product' : 'Update product'),
            ),
            if (_editingProductId != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting ? null : _resetForm,
                child: const Text('Cancel edit'),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Current products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_isLoadingProducts)
              const Center(child: CircularProgressIndicator())
            else if (_products.isEmpty)
              const Text('No products added yet.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (_, index) {
                    final product = _products[index];
                    return ListTile(
                      title: Text(product['name']?.toString() ?? 'Product'),
                      subtitle: Text('${product['unit']?.toString() ?? 'unit'} • ₹${(product['price'] as num? ?? 0).toStringAsFixed(0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _startEditing(product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteProduct(product['id']?.toString() ?? ''),
                          ),
                        ],
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
