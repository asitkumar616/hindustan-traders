import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';
import '../services/voice_product_parser.dart';

class OwnerProductManagementScreen extends StatefulWidget {
  const OwnerProductManagementScreen({super.key, required this.businessId, this.autoOpenAdd = false});

  final String businessId;
  final bool autoOpenAdd;

  @override
  State<OwnerProductManagementScreen> createState() => _OwnerProductManagementScreenState();
}

class _OwnerProductManagementScreenState extends State<OwnerProductManagementScreen> {
  final stt.SpeechToText _productVoice = stt.SpeechToText();
  bool _isLoadingProducts = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showProductDialog();
      });
    }
  }

  @override
  void dispose() {
    _productVoice.stop();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId);
      if (!mounted) return;
      setState(() => _products = products);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load products: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<void> _showProductDialog({Map<String, dynamic>? product}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: product?['name']?.toString() ?? '');
    final unitController = TextEditingController(text: product?['unit']?.toString() ?? 'kg');
    final priceController = TextEditingController(
      text: product == null ? '0' : (product['price'] as num? ?? 0).toString(),
    );
    final isEditing = product != null;
    bool submitting = false;
    bool listening = false;
    String voiceStatus = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> toggleVoiceFill() async {
              if (listening) {
                await _productVoice.stop();
                setDialogState(() {
                  listening = false;
                  voiceStatus = 'Stopped.';
                });
                return;
              }

              final permission = await Permission.microphone.request();
              if (!context.mounted) return;

              if (permission.isDenied || permission.isPermanentlyDenied) {
                setDialogState(() => voiceStatus = 'Microphone permission denied.');
                return;
              }

              final available = _productVoice.isAvailable || await _productVoice.initialize();
              if (!context.mounted) return;

              if (!available) {
                setDialogState(() => voiceStatus = 'Speech recognition unavailable.');
                return;
              }

              setDialogState(() {
                listening = true;
                voiceStatus = 'Listening... say product name, unit, and price.';
              });

              await _productVoice.listen(
                onResult: (result) {
                  if (!context.mounted) return;
                  if (result.finalResult) {
                    final draft = VoiceProductParser.parse(result.recognizedWords);
                    setDialogState(() {
                      listening = false;
                      voiceStatus = 'Heard: "${result.recognizedWords}"';
                      if (draft.name != null) nameController.text = draft.name!;
                      if (draft.unit != null) unitController.text = draft.unit!;
                      if (draft.price != null) priceController.text = draft.price!.toStringAsFixed(0);
                    });
                  }
                },
                listenFor: const Duration(seconds: 12),
                pauseFor: const Duration(seconds: 3),
                partialResults: false,
              );
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit product' : 'Add product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: submitting ? null : toggleVoiceFill,
                        icon: Icon(listening ? Icons.stop : Icons.mic),
                        label: Text(listening ? 'Stop listening' : 'Speak to fill'),
                      ),
                    ),
                    if (voiceStatus.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(voiceStatus, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Product name'),
                    ),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          _productVoice.stop();
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          await _productVoice.stop();
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Product name is required.')),
                            );
                            return;
                          }

                          setDialogState(() => submitting = true);
                          try {
                            final unit = unitController.text.trim().isEmpty ? 'unit' : unitController.text.trim();
                            final price = double.tryParse(priceController.text.trim()) ?? 0;

                            if (isEditing) {
                              await CustomerBusinessService.updateProduct(
                                productId: product['id']?.toString() ?? '',
                                name: nameController.text.trim(),
                                unit: unit,
                                price: price,
                              );
                            } else {
                              await CustomerBusinessService.createProduct(
                                businessId: widget.businessId,
                                name: nameController.text.trim(),
                                unit: unit,
                                price: price,
                              );
                            }

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadProducts();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Product updated.' : 'Product added.')),
                            );
                          } catch (error) {
                            setDialogState(() => submitting = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Unable to save product: $error')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Save' : 'Add product'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await CustomerBusinessService.deleteProduct(productId: productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product removed')));
      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove product: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(onPressed: _loadProducts, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingProducts
            ? const Center(child: CircularProgressIndicator())
            : _products.isEmpty
                ? const Center(child: Text('No products added yet. Tap "Add product" to create one.'))
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (_, index) {
                      final product = _products[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(product['name']?.toString() ?? 'Product'),
                          subtitle: Text(
                            '${product['unit']?.toString() ?? 'unit'} • ₹${(product['price'] as num? ?? 0).toStringAsFixed(0)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showProductDialog(product: product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteProduct(product['id']?.toString() ?? ''),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
