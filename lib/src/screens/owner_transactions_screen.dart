import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'invoice_review_screen.dart';

class OwnerTransactionsScreen extends StatefulWidget {
  const OwnerTransactionsScreen({super.key, required this.businessId, this.todayOnly = false});

  final String businessId;
  final bool todayOnly;

  @override
  State<OwnerTransactionsScreen> createState() => _OwnerTransactionsScreenState();
}

class _OwnerTransactionsScreenState extends State<OwnerTransactionsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _invoices = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    try {
      var query = Supabase.instance.client
          .from('invoices')
          .select('id, invoice_number, status, total, paid_amount, balance_amount, created_at, customer:customers!invoices_customer_id_fkey(display_name)')
          .eq('business_id', widget.businessId)
          .neq('status', 'draft');

      if (widget.todayOnly) {
        final startOfDay = DateTime.now().toUtc();
        final dayStart = DateTime.utc(startOfDay.year, startOfDay.month, startOfDay.day);
        query = query.gte('created_at', dayStart.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _invoices = List<Map<String, dynamic>>.from(response as List));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load transactions: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _invoices.fold<num>(0, (sum, invoice) => sum + ((invoice['total'] as num?) ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todayOnly ? "Today's Sales" : 'Transactions'),
        actions: [
          IconButton(onPressed: _loadInvoices, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      Text('across ${_invoices.length} sale(s)', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Expanded(
                  child: _invoices.isEmpty
                      ? const Center(child: Text('No sales recorded yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _invoices.length,
                          itemBuilder: (_, index) {
                            final invoice = _invoices[index];
                            final customer = (invoice['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                            final balance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
                            final status = ((invoice['status'] as String?) ?? 'pending').toUpperCase();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(invoice['invoice_number']?.toString() ?? 'Invoice'),
                                subtitle: Text(
                                  '${customer['display_name'] ?? 'Customer'} • ₹${((invoice['total'] as num?) ?? 0).toStringAsFixed(0)}'
                                  '${balance > 0 ? ' • Pending ₹${balance.toStringAsFixed(0)}' : ''}',
                                ),
                                trailing: Chip(label: Text(status), visualDensity: VisualDensity.compact),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => InvoiceReviewScreen(invoiceId: invoice['id'].toString())),
                                  ).then((_) {
                                    if (mounted) _loadInvoices();
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
