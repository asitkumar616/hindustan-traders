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
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(onPressed: _loadInvoices, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search invoice number or customer',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      FilterChip(
                        label: const Text('Draft'),
                        selected: _statusFilter == 'draft',
                        onSelected: (_) => setState(() => _statusFilter = 'draft'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(child: Text('No invoices found.'))
                        : ListView(
                            children: groups.entries.expand((entry) {
                              return [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black54),
                                  ),
                                ),
                                ...entry.value.map((invoice) {
                                  final customer = (invoice['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                                  final status = ((invoice['status'] as String?) ?? 'draft').toUpperCase();
                                  final balance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
                                  final paid = ((invoice['paid_amount'] as num?) ?? 0).toDouble();
                                  final isPaid = ((invoice['status'] as String?) ?? 'draft').toLowerCase() == 'paid';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(invoice['invoice_number']?.toString() ?? 'Invoice'),
                                      subtitle: Text(
                                        '${customer['display_name'] ?? 'Customer'} • ₹${((invoice['total'] as num?) ?? 0).toStringAsFixed(0)}\n'
                                        'Paid ₹${paid.toStringAsFixed(0)} • Pending ₹${balance.toStringAsFixed(0)}',
                                      ),
                                      isThreeLine: true,
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
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
                                    ),
                                  );
                                }),
                              ];
                            }).toList(),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
