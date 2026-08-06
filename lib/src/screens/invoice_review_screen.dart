import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvoiceReviewScreen extends StatefulWidget {
  const InvoiceReviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('invoices')
          .select('id, business_id, customer_id, invoice_number, status, total, paid_amount, balance_amount, created_at, customer:customers!invoices_customer_id_fkey(display_name, phone)')
          .eq('id', widget.invoiceId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _invoice = response;
          _loading = false;
        });
      }

      await _loadPayments();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadPayments() async {
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select('amount, payment_method, payment_status, created_at')
          .eq('invoice_id', widget.invoiceId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _payments = [];
        });
      }
    }
  }

  Future<void> _updateInvoiceStatus(String status) async {
    if (_invoice == null) return;

    setState(() => _updatingStatus = true);
    try {
      if (status == 'paid') {
        final businessId = _invoice!['business_id']?.toString();
        final customerId = _invoice!['customer_id']?.toString();
        final totalAmount = ((_invoice!['total'] as num?) ?? 0).toDouble();
        final currentPaidAmount = ((_invoice!['paid_amount'] as num?) ?? 0).toDouble();
        final currentBalance = ((_invoice!['balance_amount'] as num?) ?? 0).toDouble();
        final paymentAmount = currentBalance > 0 ? currentBalance : totalAmount - currentPaidAmount;

        if (businessId != null && customerId != null && paymentAmount > 0) {
          final existingPayments = await Supabase.instance.client
              .from('payments')
              .select('id')
              .eq('invoice_id', widget.invoiceId)
              .limit(1);

          if (existingPayments.isEmpty) {
            await Supabase.instance.client.from('payments').insert({
              'business_id': businessId,
              'customer_id': customerId,
              'invoice_id': widget.invoiceId,
              'amount': paymentAmount,
              'payment_method': 'cash',
              'payment_status': 'completed',
              'reference_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
            });
          }

          await Supabase.instance.client.from('ledger_entries').insert({
            'business_id': businessId,
            'customer_id': customerId,
            'invoice_id': widget.invoiceId,
            'entry_type': 'payment',
            'debit': 0,
            'credit': paymentAmount,
            'balance': 0,
          });
        }

        await Supabase.instance.client.from('invoices').update({
          'status': status,
          'paid_amount': currentPaidAmount + paymentAmount,
          'balance_amount': (currentBalance - paymentAmount).clamp(0, double.infinity),
        }).eq('id', widget.invoiceId);
      } else {
        await Supabase.instance.client.from('invoices').update({'status': status}).eq('id', widget.invoiceId);
      }

      if (mounted) {
        setState(() {
          _invoice!['status'] = status;
          if (status == 'paid') {
            final currentBalance = ((_invoice!['balance_amount'] as num?) ?? 0).toDouble();
            final paymentAmount = currentBalance > 0 ? currentBalance : (((_invoice!['total'] as num?) ?? 0).toDouble() - ((_invoice!['paid_amount'] as num?) ?? 0).toDouble());
            _invoice!['paid_amount'] = (((_invoice!['paid_amount'] as num?) ?? 0).toDouble() + paymentAmount);
            _invoice!['balance_amount'] = (currentBalance - paymentAmount).clamp(0, double.infinity);
          }
          _updatingStatus = false;
        });
      }

      if (status == 'paid') {
        await _loadPayments();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _updatingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update invoice status.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice review')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invoice == null
                ? const Center(child: Text('Invoice not found.'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invoice!['invoice_number']?.toString() ?? 'Invoice',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Chip(
                        label: Text(((_invoice!['status'] as String?) ?? 'draft').toUpperCase()),
                      ),
                      const SizedBox(height: 12),
                      Text('Customer: ${(_invoice!['customer'] as Map<String, dynamic>?)?['display_name'] ?? 'Customer'}'),
                      const SizedBox(height: 8),
                      Text('Amount: ₹${((_invoice!['total'] as num?) ?? 0).toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      Text('Balance: ₹${((_invoice!['balance_amount'] as num?) ?? 0).toStringAsFixed(0)}'),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        children: [
                          ElevatedButton(
                            onPressed: _updatingStatus ? null : () => _updateInvoiceStatus('draft'),
                            child: const Text('Draft'),
                          ),
                          OutlinedButton(
                            onPressed: _updatingStatus ? null : () => _updateInvoiceStatus('pending'),
                            child: const Text('Pending'),
                          ),
                          FilledButton(
                            onPressed: _updatingStatus ? null : () => _updateInvoiceStatus('paid'),
                            child: const Text('Paid'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Payment history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (_payments.isEmpty)
                        const Text('No payments recorded yet.')
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _payments.length,
                            itemBuilder: (_, index) {
                              final payment = _payments[index];
                              final amount = ((payment['amount'] as num?) ?? 0).toStringAsFixed(0);
                              final createdAt = payment['created_at'];
                              final dateText = createdAt != null ? createdAt.toString() : '—';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('₹$amount via ${payment['payment_method'] ?? 'cash'}'),
                                subtitle: Text('$dateText • ${payment['payment_status'] ?? 'completed'}'),
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
