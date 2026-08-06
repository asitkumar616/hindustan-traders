import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'invoice_review_screen.dart';

class OwnerInvoicesScreen extends StatefulWidget {
  const OwnerInvoicesScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<OwnerInvoicesScreen> createState() => _OwnerInvoicesScreenState();
}

class _OwnerInvoicesScreenState extends State<OwnerInvoicesScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('invoices')
          .select('id, customer_id, invoice_number, status, total, balance_amount, created_at, customer:customers!invoices_customer_id_fkey(display_name)')
          .eq('business_id', widget.businessId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _invoices = List<Map<String, dynamic>>.from(response as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markInvoicePaid(Map<String, dynamic> invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark invoice as paid?'),
        content: const Text('This will record the payment and close the balance for this invoice.'),
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

    if (mounted) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _invoices.where((invoice) {
      final status = ((invoice['status'] as String?) ?? 'draft').toLowerCase();
      switch (_statusFilter) {
        case 'outstanding':
          return status != 'paid';
        case 'paid':
          return status == 'paid';
        case 'pending':
          return status == 'pending';
        case 'draft':
          return status == 'draft';
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(onPressed: _loadInvoices, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _statusFilter == 'all',
                        onSelected: (_) => setState(() => _statusFilter = 'all'),
                      ),
                      FilterChip(
                        label: const Text('Outstanding'),
                        selected: _statusFilter == 'outstanding',
                        onSelected: (_) => setState(() => _statusFilter = 'outstanding'),
                      ),
                      FilterChip(
                        label: const Text('Pending'),
                        selected: _statusFilter == 'pending',
                        onSelected: (_) => setState(() => _statusFilter = 'pending'),
                      ),
                      FilterChip(
                        label: const Text('Paid'),
                        selected: _statusFilter == 'paid',
                        onSelected: (_) => setState(() => _statusFilter = 'paid'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredInvoices.isEmpty
                        ? const Center(child: Text('No invoices yet.'))
                        : ListView.builder(
                            itemCount: filteredInvoices.length,
                            itemBuilder: (_, index) {
                              final invoice = filteredInvoices[index];
                              final customer = (invoice['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                              final status = ((invoice['status'] as String?) ?? 'draft').toUpperCase();
                              final balance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
                              final isPaid = ((invoice['status'] as String?) ?? 'draft').toLowerCase() == 'paid';

                              return ListTile(
                                title: Text(invoice['invoice_number']?.toString() ?? 'Invoice'),
                                subtitle: Text('${customer['display_name'] ?? 'Customer'} • ₹${((invoice['total'] as num?) ?? 0).toStringAsFixed(0)} • Balance ₹${balance.toStringAsFixed(0)}'),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    Chip(label: Text(status), visualDensity: VisualDensity.compact),
                                    if (!isPaid)
                                      TextButton(
                                        onPressed: () => _markInvoicePaid(invoice),
                                        child: const Text('Mark paid'),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceReviewScreen(invoiceId: invoice['id'].toString()),
                                    ),
                                  ).then((_) {
                                    if (mounted) {
                                      _loadInvoices();
                                    }
                                  });
                                },
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
