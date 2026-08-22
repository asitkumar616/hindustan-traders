import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_voice_bottom_nav.dart';
import '../widgets/owner_nav_drawer.dart';
import '../widgets/voice_order_card.dart';
import 'invoice_review_screen.dart';
import 'login_screen.dart';
import 'owner_orders_screen.dart';
import 'owner_product_management_screen.dart';

class OwnerInvoicesScreen extends StatefulWidget {
  const OwnerInvoicesScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerInvoicesScreen> createState() => _OwnerInvoicesScreenState();
}

class _OwnerInvoicesScreenState extends State<OwnerInvoicesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String _statusFilter = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('invoices')
          .select('id, customer_id, invoice_number, status, total, paid_amount, balance_amount, created_at, customer:customers!invoices_customer_id_fkey(display_name)')
          .eq('business_id', widget.businessId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _invoices = List<Map<String, dynamic>>.from(response as List);
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load invoices: $error')),
        );
      }
    }
  }

  Future<void> _markInvoicePaid(Map<String, dynamic> invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark invoice as paid?'),
        content: const Text('This will record the full remaining balance as paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    final invoiceId = invoice['id'].toString();
    final balance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
    final customerId = invoice['customer_id']?.toString();

    try {
      if (balance > 0 && customerId != null) {
        await Supabase.instance.client.from('payments').insert({
          'business_id': widget.businessId,
          'customer_id': customerId,
          'invoice_id': invoiceId,
          'amount': balance,
          'payment_method': 'cash',
          'payment_status': 'completed',
          'reference_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
        });

        await Supabase.instance.client.from('ledger_entries').insert({
          'business_id': widget.businessId,
          'customer_id': customerId,
          'invoice_id': invoiceId,
          'entry_type': 'payment',
          'debit': 0,
          'credit': balance,
          'balance': 0,
        });
      }

      await Supabase.instance.client.from('invoices').update({
        'status': 'paid',
        'paid_amount': ((invoice['paid_amount'] as num?) ?? 0).toDouble() + balance,
        'balance_amount': 0,
      }).eq('id', invoiceId);

      if (!mounted) return;
      setState(() {
        _invoices = _invoices.map((item) {
          if (item['id'].toString() == invoiceId) {
            return {
              ...item,
              'status': 'paid',
              'paid_amount': ((item['paid_amount'] as num?) ?? 0).toDouble() + balance,
              'balance_amount': 0,
            };
          }
          return item;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice marked as paid.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to mark invoice paid: $error')),
      );
    }
  }

  String _dateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();

    final filteredInvoices = _invoices.where((invoice) {
      final status = ((invoice['status'] as String?) ?? 'draft').toLowerCase();
      final statusMatches = switch (_statusFilter) {
        'outstanding' => status != 'paid',
        'paid' => status == 'paid',
        'pending' => status == 'pending',
        'draft' => status == 'draft',
        _ => true,
      };
      if (!statusMatches) return false;

      if (query.isEmpty) return true;
      final invoiceNumber = (invoice['invoice_number']?.toString() ?? '').toLowerCase();
      final customer = (invoice['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final customerName = (customer['display_name']?.toString() ?? '').toLowerCase();
      return invoiceNumber.contains(query) || customerName.contains(query);
    }).toList();

    // Group by day, preserving the newest-first order already applied by the query.
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final invoice in filteredInvoices) {
      final createdAt = invoice['created_at'] as String?;
      final parsed = createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() : null;
      final label = parsed != null ? _dateGroupLabel(parsed) : 'UNKNOWN DATE';
      groups.putIfAbsent(label, () => []).add(invoice);
    }

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
                      const Expanded(child: Text('Invoices', style: AppTextStyles.heading)),
                      IconButton(
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search invoice number or customer',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                children: [
                  AppFilterChip(
                    label: 'All',
                    selected: _statusFilter == 'all',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'all'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Outstanding',
                    selected: _statusFilter == 'outstanding',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'outstanding'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Pending',
                    selected: _statusFilter == 'pending',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'pending'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Paid',
                    selected: _statusFilter == 'paid',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'paid'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Draft',
                    selected: _statusFilter == 'draft',
                    selectedColor: AppColors.ownerPrimary,
                    onTap: () => setState(() => _statusFilter = 'draft'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInvoices,
                child: _loading
                    ? const AppLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        children: groups.isEmpty
                            ? const [
                                AppEmptyState(
                                  icon: Icons.description_outlined,
                                  title: 'No Invoices',
                                  message: 'No invoices match this filter yet.',
                                ),
                              ]
                            : groups.entries.expand((entry) {
                                return [
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                                    child: Text(entry.key, style: AppTextStyles.sectionLabel),
                                  ),
                                  ...entry.value.map(
                                    (invoice) => Padding(
                                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                      child: _InvoiceCard(
                                        invoice: invoice,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => InvoiceReviewScreen(invoiceId: invoice['id'].toString()),
                                            ),
                                          ).then((_) {
                                            if (mounted) _loadInvoices();
                                          });
                                        },
                                        onMarkPaid: () => _markInvoicePaid(invoice),
                                      ),
                                    ),
                                  ),
                                ];
                              }).toList(),
                      ),
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
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OwnerProductManagementScreen(businessId: widget.businessId)),
            ),
          ),
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
        onVoice: () => _showVoiceOrderSheet(),
      ),
    );
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
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap, required this.onMarkPaid});

  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final customer = (invoice['customer'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final customerName = (customer['display_name']?.toString().isNotEmpty ?? false) ? customer['display_name'].toString() : 'Customer';
    final status = ((invoice['status'] as String?) ?? 'draft').toLowerCase();
    final total = ((invoice['total'] as num?) ?? 0);
    final statusStyle = _statusStyleFor(status);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(invoice['invoice_number']?.toString() ?? 'Invoice', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              Text('₹${formatIndianAmount(total)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(customerName, style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusStyle.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(statusStyle.label, style: TextStyle(color: statusStyle.fg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (status != 'paid')
                TextButton(onPressed: onMarkPaid, child: const Text('Mark Paid')),
            ],
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyleFor(String status) {
    switch (status) {
      case 'paid':
        return const _StatusStyle('Paid', Color(0xFFE1F7E8), Color(0xFF2E7D32));
      case 'pending':
        return const _StatusStyle('Pending', Color(0xFFFFF1DC), Color(0xFFC9820A));
      case 'draft':
        return const _StatusStyle('Draft', AppColors.divider, AppColors.textSecondary);
      default:
        return _StatusStyle(status, AppColors.divider, AppColors.textSecondary);
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}
