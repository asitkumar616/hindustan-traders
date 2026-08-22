import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/auth_service.dart';
import '../services/customer_business_service.dart';
import '../services/voice_product_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_voice_bottom_nav.dart';
import '../widgets/owner_nav_drawer.dart';
import '../widgets/voice_order_card.dart';
import 'add_product_voice_screen.dart';
import 'login_screen.dart';
import 'owner_orders_screen.dart';

class OwnerProductManagementScreen extends StatefulWidget {
  const OwnerProductManagementScreen({super.key, required this.businessId, this.autoOpenAdd = false});

  final String businessId;
  final bool autoOpenAdd;

  @override
  State<OwnerProductManagementScreen> createState() => _OwnerProductManagementScreenState();
}

class _OwnerProductManagementScreenState extends State<OwnerProductManagementScreen> {
  final stt.SpeechToText _productVoice = stt.SpeechToText();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoadingProducts = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
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
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProducts = query.isEmpty
          ? _products
          : _products.where((product) => (product['name']?.toString() ?? '').toLowerCase().contains(query)).toList();
    });
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await CustomerBusinessService.getProductsForBusiness(widget.businessId);
      if (!mounted) return;
      setState(() => _products = products);
      _applyFilter();
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

  void _openAddProductByVoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductVoiceScreen(businessId: widget.businessId)),
    ).then((_) => _loadProducts());
  }

  void _showVoiceOrderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(top: false, child: VoiceOrderCard(businessId: widget.businessId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surfaceMuted,
      drawer: OwnerNavDrawer(
        businessId: widget.businessId,
        onDashboard: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onNavigate: (screen) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
        onLogout: () async {
          Navigator.pop(context);
          await AuthService.signOut();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.textPrimary,
                      ),
                      const Expanded(child: Text('Products', style: AppTextStyles.heading)),
                      IconButton(
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SearchField(controller: _searchController),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                child: _isLoadingProducts
                    ? const AppLoadingState()
                    : _filteredProducts.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            children: [
                              _products.isEmpty
                                  ? const AppEmptyState(
                                      icon: Icons.inventory_2_outlined,
                                      title: 'No Products Yet',
                                      message: 'Add your first product to get started.',
                                    )
                                  : const AppEmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: 'No Matches',
                                      message: 'No products match your search.',
                                    ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (_, index) {
                              final product = _filteredProducts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OwnerProductCard(
                                  product: product,
                                  onEdit: () => _showProductDialog(product: product),
                                  onDelete: () => _deleteProduct(product['id']?.toString() ?? ''),
                                ),
                              );
                            },
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Add Product',
                      icon: Icons.add,
                      onPressed: () => _showProductDialog(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _openAddProductByVoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ownerPrimary,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.mic_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppVoiceBottomNav(
        accentDark: AppColors.ownerPrimaryDark,
        accentLight: AppColors.ownerPrimaryLight,
        leftItems: [
          AppNavItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.maybePop(context)),
          const AppNavItem(icon: Icons.inventory_2_rounded, label: 'Products', active: true),
        ],
        rightItems: [
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OwnerOrdersScreen(businessId: widget.businessId)),
            ),
          ),
          AppNavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: () => _scaffoldKey.currentState?.openDrawer()),
        ],
        onVoice: _showVoiceOrderSheet,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Search products...',
          prefixIcon: Icon(Icons.search_rounded),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _OwnerProductCard extends StatelessWidget {
  const _OwnerProductCard({required this.product, required this.onEdit, required this.onDelete});

  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Product';
    final unit = product['unit']?.toString() ?? 'unit';
    final price = (product['price'] as num?) ?? 0;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.ownerPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.ownerPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text('₹${formatIndianAmount(price)} / $unit', style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE1F7E8), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: const Text('Active', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), color: AppColors.textSecondary),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), color: AppColors.danger),
        ],
      ),
    );
  }
}
