import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvoiceReviewScreen extends StatefulWidget {
  const InvoiceReviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _lineItems = [];
  bool _loading = true;
  bool _recordingPayment = false;

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
          .select(
            'id, business_id, customer_id, order_id, invoice_number, status, total, paid_amount, balance_amount, created_at, '
            'customer:customers!invoices_customer_id_fkey(display_name, phone)',
          )
          .eq('id', widget.invoiceId)
          .maybeSingle();

      if (mounted) {
        setState(() => _invoice = response);
      }

      final orderId = response?['order_id']?.toString();
      if (orderId != null && orderId.isNotEmpty) {
        await _loadLineItems(orderId);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load invoice: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadLineItems(String orderId) async {
    try {
      final response = await Supabase.instance.client
          .from('order_items')
          .select('id, quantity, unit, price, amount, product:products!order_items_product_id_fkey(name)')
          .eq('order_id', orderId);

      if (!mounted) return;
      setState(() => _lineItems = List<Map<String, dynamic>>.from(response as List));
    } catch (_) {
      if (mounted) {
        setState(() => _lineItems = []);
      }
    }
  }

  Future<void> _showRecordPaymentDialog() async {
    final invoice = _invoice;
    if (invoice == null) return;

    final balance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This invoice has no pending balance.')));
      return;
    }

    final amountController = TextEditingController(text: balance.toStringAsFixed(0));
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending balance: ₹${balance.toStringAsFixed(0)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Payment amount'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid payment amount.')),
                            );
                            return;
                          }
                          if (amount > balance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment amount cannot exceed the pending balance.')),
                            );
                            return;
                          }

                          setDialogState(() => submitting = true);
                          try {
                            await _recordPayment(amount);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (error) {
                            setDialogState(() => submitting = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Unable to record payment: $error')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _recordPayment(double amount) async {
    final invoice = _invoice!;
    final businessId = invoice['business_id']?.toString();
    final customerId = invoice['customer_id']?.toString();
    final currentPaid = ((invoice['paid_amount'] as num?) ?? 0).toDouble();
    final currentBalance = ((invoice['balance_amount'] as num?) ?? 0).toDouble();
    final currentStatus = (invoice['status'] as String?) ?? 'draft';

    setState(() => _recordingPayment = true);

    final newPaid = currentPaid + amount;
    final newBalance = (currentBalance - amount).clamp(0, double.infinity).toDouble();
    final newStatus = newBalance <= 0 ? 'paid' : (currentStatus == 'draft' ? 'pending' : currentStatus);

    if (businessId != null && customerId != null) {
      await Supabase.instance.client.from('payments').insert({
        'business_id': businessId,
        'customer_id': customerId,
        'invoice_id': widget.invoiceId,
        'amount': amount,
        'payment_method': 'cash',
        'payment_status': 'completed',
        'reference_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
      });

      await Supabase.instance.client.from('ledger_entries').insert({
        'business_id': businessId,
        'customer_id': customerId,
        'invoice_id': widget.invoiceId,
        'entry_type': 'payment',
        'debit': 0,
        'credit': amount,
        'balance': newBalance,
      });
    }

    await Supabase.instance.client.from('invoices').update({
      'status': newStatus,
      'paid_amount': newPaid,
      'balance_amount': newBalance,
    }).eq('id', widget.invoiceId);

    if (!mounted) return;
    setState(() {
      _invoice = {
        ..._invoice!,
        'status': newStatus,
        'paid_amount': newPaid,
        'balance_amount': newBalance,
      };
      _recordingPayment = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded.')));
  }

  void _showCustomerDetails() {
    final customer = (_invoice?['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer['display_name']?.toString() ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(customer['phone']?.toString() ?? 'No phone on record'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _shareInvoice() {
    final invoice = _invoice;
    if (invoice == null) return;

    final customer = (invoice['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final buffer = StringBuffer()
      ..writeln('Invoice ${invoice['invoice_number'] ?? ''}')
      ..writeln('Customer: ${customer['display_name'] ?? 'Customer'}')
      ..writeln('---');

    for (final item in _lineItems) {
      final product = (item['product'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final name = product['name']?.toString() ?? 'Item';
      final qty = item['quantity'];
      final unit = item['unit']?.toString() ?? '';
      final amount = (item['amount'] as num?) ?? 0;
      buffer.writeln('$name x $qty $unit - ₹${amount.toStringAsFixed(0)}');
    }

    buffer
      ..writeln('---')
      ..writeln('Total: ₹${((invoice['total'] as num?) ?? 0).toStringAsFixed(0)}')
      ..writeln('Paid: ₹${((invoice['paid_amount'] as num?) ?? 0).toStringAsFixed(0)}')
      ..writeln('Pending: ₹${((invoice['balance_amount'] as num?) ?? 0).toStringAsFixed(0)}');

    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Invoice ${invoice['invoice_number'] ?? ''}'));
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final customer = (invoice?['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final createdAt = invoice?['created_at'] as String?;
    final dateText = createdAt != null ? (DateTime.tryParse(createdAt)?.toLocal().toString().split('.').first ?? createdAt) : '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : invoice == null
              ? const Center(child: Text('Invoice not found.'))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      invoice['invoice_number']?.toString() ?? 'Invoice',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Chip(label: Text(((invoice['status'] as String?) ?? 'draft').toUpperCase())),
                    const SizedBox(height: 16),
                    Text('Customer: ${customer['display_name'] ?? 'Customer'}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Date: $dateText', style: const TextStyle(color: Colors.black54)),
                    const Divider(height: 32),
                    const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_lineItems.isEmpty)
                      const Text('No item breakdown available for this invoice.', style: TextStyle(color: Colors.black54))
                    else
                      ..._lineItems.map((item) {
                        final product = (item['product'] as Map<String, dynamic>?) ?? <String, dynamic>{};
                        final name = product['name']?.toString() ?? 'Item';
                        final qty = item['quantity'];
                        final unit = item['unit']?.toString() ?? '';
                        final price = (item['price'] as num?) ?? 0;
                        final amount = (item['amount'] as num?) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('$qty $unit • ₹${price.toStringAsFixed(0)}/$unit', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 32),
                    _SummaryRow(label: 'Subtotal', value: (invoice['total'] as num?) ?? 0),
                    _SummaryRow(label: 'Paid', value: (invoice['paid_amount'] as num?) ?? 0, color: Colors.green),
                    _SummaryRow(label: 'Pending', value: (invoice['balance_amount'] as num?) ?? 0, color: Colors.red),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _recordingPayment ? null : _showRecordPaymentDialog,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Record Payment'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showCustomerDetails,
                        icon: const Icon(Icons.person_outline),
                        label: const Text('View Customer'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _shareInvoice,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share Invoice'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.color});

  final String label;
  final num value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
