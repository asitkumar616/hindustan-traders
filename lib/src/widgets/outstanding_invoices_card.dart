import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/invoice_review_screen.dart';
import '../screens/owner_invoices_screen.dart';

class OutstandingInvoicesCard extends StatefulWidget {
  const OutstandingInvoicesCard({super.key, required this.businessId});

  final String businessId;

  @override
  State<OutstandingInvoicesCard> createState() => _OutstandingInvoicesCardState();
}

class _OutstandingInvoicesCardState extends State<OutstandingInvoicesCard> {
  num _outstanding = 0;
  int _count = 0;
  List<Map<String, dynamic>> _recentInvoices = [];
  bool _loading = true;
  String? _processingInvoiceId;

  @override
  void initState() {
    super.initState();
    _loadOutstanding();
  }

  Future<void> _loadOutstanding() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('invoices')
          .select('id, customer_id, invoice_number, balance_amount, status')
          .eq('business_id', widget.businessId)
          .neq('status', 'paid')
          .order('created_at', ascending: false)
          .limit(3);

      final invoices = List<Map<String, dynamic>>.from(response as List);
      final outstanding = invoices.fold<num>(0, (sum, invoice) => sum + ((invoice['balance_amount'] as num?) ?? 0));

      if (mounted) {
        setState(() {
          _outstanding = outstanding;
          _count = invoices.length;
          _recentInvoices = invoices;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _outstanding = 0;
          _count = 0;
          _recentInvoices = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OwnerInvoicesScreen(businessId: widget.businessId),
          ),
        );
        if (mounted) {
          _loadOutstanding();
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Outstanding invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: _loadOutstanding,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Text('Loading...')
              else ...[
                Text('₹${_outstanding.toStringAsFixed(0)} across $_count invoice(s)'),
                const SizedBox(height: 8),
                if (_recentInvoices.isEmpty)
                  const Text('No unpaid invoices found.')
                else
                  ..._recentInvoices.map((invoice) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceReviewScreen(invoiceId: invoice['id'].toString()),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Text('${invoice['invoice_number']} • ₹${((invoice['balance_amount'] as num?) ?? 0).toStringAsFixed(0)}'),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios, size: 14),
                                  ],
                                ),
                              ),
                            ),
                            _processingInvoiceId == invoice['id'].toString()
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('Processing...'),
                                  )
                                : TextButton(
                                    onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Mark invoice as paid?'),
                                    content: const Text('This will record the settlement and update the ledger.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed != true) {
                                  return;
                                }

                                final invoiceId = invoice['id'].toString();
                                setState(() {
                                  _processingInvoiceId = invoiceId;
                                });
                                final balance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
                                final businessId = widget.businessId;
                                final customerId = invoice['customer_id']?.toString();

                                if (balance > 0 && customerId != null) {
                                  await Supabase.instance.client.from('payments').insert({
                                    'business_id': businessId,
                                    'customer_id': customerId,
                                    'invoice_id': invoiceId,
                                    'amount': balance,
                                    'payment_method': 'cash',
                                    'payment_status': 'completed',
                                    'reference_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
                                  });

                                  await Supabase.instance.client.from('ledger_entries').insert({
                                    'business_id': businessId,
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
                                  'paid_amount': balance,
                                  'balance_amount': 0,
                                }).eq('id', invoiceId);

                                if (mounted) {
                                  setState(() {
                                    _recentInvoices.removeWhere((item) => item['id'].toString() == invoiceId);
                                    _count = _recentInvoices.length;
                                    _outstanding = _recentInvoices.fold<num>(0, (sum, item) => sum + ((item['balance_amount'] as num?) ?? 0));
                                    _processingInvoiceId = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invoice marked as paid.')),
                                  );
                                  _loadOutstanding();
                                }
                              },
                              child: const Text('Mark paid'),
                            ),
                          ],
                        ),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
