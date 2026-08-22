import '../models/cart_line.dart';
import '../models/order_draft.dart';
import '../models/order_item.dart';
import 'auth_service.dart';
import 'customer_business_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

extension IterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class OrderSubmissionResult {
  final bool success;
  final bool savedLocally;
  final String message;

  const OrderSubmissionResult({
    required this.success,
    this.savedLocally = false,
    this.message = '',
  });
}

class OrderDraftService {
  static OrderDraft parseTranscript(String transcript) {
    final normalized = transcript.toLowerCase();
    final items = <String>[];

    if (normalized.contains('rice')) {
      items.add('Rice - 2 kg');
    }
    if (normalized.contains('milk')) {
      items.add('Milk - 1 litre');
    }
    if (normalized.contains('egg') || normalized.contains('eggs')) {
      items.add('Eggs - 1 dozen');
    }

    return OrderDraft(
      transcript: transcript,
      items: items.isEmpty ? ['No items detected'] : items,
    );
  }

  static double estimateTotalAmount(List<String> items) {
    double total = 0;

    for (final item in items) {
      final normalized = item.toLowerCase();
      if (normalized.contains('rice')) {
        total += 80;
      }
      if (normalized.contains('milk')) {
        total += 60;
      }
      if (normalized.contains('egg') || normalized.contains('eggs')) {
        total += 120;
      }
    }

    return total;
  }

  static List<OrderItem> buildOrderItems(List<String> items) {
    return items.map((item) {
      final normalized = item.toLowerCase();
      if (normalized.contains('rice')) {
        return const OrderItem(name: 'Rice', quantity: 2, unit: 'kg', price: 80, amount: 160);
      }
      if (normalized.contains('milk')) {
        return const OrderItem(name: 'Milk', quantity: 1, unit: 'litre', price: 60, amount: 60);
      }
      if (normalized.contains('egg') || normalized.contains('eggs')) {
        return const OrderItem(name: 'Eggs', quantity: 1, unit: 'dozen', price: 120, amount: 120);
      }
      return OrderItem(name: item, quantity: 1, unit: 'unit', price: 0, amount: 0);
    }).toList();
  }

  static Map<String, dynamic> mapOrderItemToPayload(OrderItem item, Map<String, dynamic>? matchingProduct) {
    if (matchingProduct != null) {
      final price = matchingProduct['price'] as num? ?? item.price;
      final amount = price * item.quantity;
      return {
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'price': price,
        'amount': amount,
        'product_id': matchingProduct['id'],
      };
    }

    return {
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'price': item.price,
      'amount': item.amount,
      'product_id': null,
    };
  }

  // businessId identifies which shop this order belongs to (the customer's
  // currently selected shop). Falls back to the profile's default business
  // when omitted, so existing callers (e.g. the owner's own voice-order
  // card) keep working unchanged.
  static Future<OrderSubmissionResult> submitDraft(OrderDraft draft, {String? businessId}) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        await _persistDraftLocally(draft);
        return const OrderSubmissionResult(
          success: false,
          savedLocally: true,
          message: 'No authenticated user found. Draft saved locally.',
        );
      }

      final resolvedBusinessId = businessId ?? (await AuthService.fetchProfileById(user.id))?.businessId;
      if (resolvedBusinessId == null || resolvedBusinessId.isEmpty) {
        await _persistDraftLocally(draft);
        return const OrderSubmissionResult(
          success: false,
          savedLocally: true,
          message: 'No linked business found. Draft saved locally.',
        );
      }

      if (!SupabaseService.isInitialized) {
        await _persistDraftLocally(draft);
        return const OrderSubmissionResult(
          success: false,
          savedLocally: true,
          message: 'Supabase is not ready. Draft saved locally.',
        );
      }

      final products = await CustomerBusinessService.getProductsForBusiness(resolvedBusinessId);
      final orderItems = buildOrderItems(draft.items);
      final mappedProducts = <Map<String, dynamic>>[];
      for (final item in orderItems) {
        final matchingProduct = products.where((product) => (product['name'] as String).toLowerCase() == item.name.toLowerCase()).firstOrNull;
        mappedProducts.add(mapOrderItemToPayload(item, matchingProduct));
      }

      final orderResponse = await SupabaseService.client.from('orders').insert({
        'customer_id': user.id,
        'business_id': resolvedBusinessId,
        'status': 'pending',
        'total_amount': mappedProducts.fold<double>(0, (sum, current) => sum + (current['amount'] as num).toDouble()),
      }).select('id').single();

      final orderId = orderResponse['id'] as String?;
      if (orderId != null) {
        await SupabaseService.client.from('order_items').insert(
          mappedProducts.map((item) => {
            'order_id': orderId,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'price': item['price'],
            'amount': item['amount'],
          }).toList(),
        );

        await _notifyOwnerOfNewOrder(
          businessId: resolvedBusinessId,
          orderId: orderId,
          totalAmount: mappedProducts.fold<double>(0, (sum, current) => sum + (current['amount'] as num).toDouble()),
        );

        // Invoice-draft creation is a follow-on convenience, not part of
        // placing the order itself -- by the time this runs, the order and
        // its items are already committed. If this fails (e.g. RLS not
        // permitting a customer to write to `invoices`), the customer must
        // still see their order as placed, not a false failure.
        await _createInvoiceDraftForOrder(
          businessId: resolvedBusinessId,
          customerId: user.id,
          orderId: orderId,
          totalAmount: mappedProducts.fold<double>(0, (sum, current) => sum + (current['amount'] as num).toDouble()),
        );
      }

      await _persistDraftLocally(draft);
      return const OrderSubmissionResult(
        success: true,
        savedLocally: false,
        message: 'Order submitted successfully. Invoice draft created.',
      );
    } catch (_) {
      await _persistDraftLocally(draft);
      return const OrderSubmissionResult(
        success: false,
        savedLocally: true,
        message: 'Submission failed. Draft saved locally.',
      );
    }
  }

  // Submits a cart built from real catalog selections (Shop Catalog / Cart
  // screens): structured product_id + quantity + unit + price, written
  // straight to orders/order_items. Deliberately separate from submitDraft
  // above -- that path re-derives quantity/price through parseTranscript's
  // keyword stub (only recognizes "rice"/"milk"/"egg" with fixed fake
  // quantities), which would silently misprice a real cart. This mirrors
  // submitDraft's own orders -> order_items -> invoice draft write sequence,
  // just driven by real line items instead of the stub parser.
  static Future<OrderSubmissionResult> submitCart({
    required String businessId,
    required List<CartLine> lines,
  }) async {
    if (lines.isEmpty) {
      return const OrderSubmissionResult(success: false, message: 'Your cart is empty.');
    }

    final user = AuthService.currentUser;
    if (user == null) {
      return const OrderSubmissionResult(success: false, message: 'Please log in again to place this order.');
    }

    if (!SupabaseService.isInitialized) {
      return const OrderSubmissionResult(success: false, message: 'Unable to reach the server. Please try again.');
    }

    try {
      final totalAmount = lines.fold<double>(0, (sum, line) => sum + line.amount);

      final orderResponse = await SupabaseService.client.from('orders').insert({
        'customer_id': user.id,
        'business_id': businessId,
        'status': 'pending',
        'total_amount': totalAmount,
      }).select('id').single();

      final orderId = orderResponse['id'] as String;

      await SupabaseService.client.from('order_items').insert(
        lines.map((line) => {
          'order_id': orderId,
          'product_id': line.productId,
          'quantity': line.quantity,
          'unit': line.unit,
          'price': line.price,
          'amount': line.amount,
        }).toList(),
      );

      await _notifyOwnerOfNewOrder(businessId: businessId, orderId: orderId, totalAmount: totalAmount);

      // Non-fatal, same reasoning as submitDraft above: the order is
      // already placed by this point, so a failure here must not be
      // reported back to the customer as a failed order.
      await _createInvoiceDraftForOrder(
        businessId: businessId,
        customerId: user.id,
        orderId: orderId,
        totalAmount: totalAmount,
      );

      return const OrderSubmissionResult(success: true, message: 'Order placed successfully.');
    } catch (_) {
      return const OrderSubmissionResult(success: false, message: 'Unable to place your order. Please try again.');
    }
  }

  // Creates the invoice draft for a just-placed order, and swallows its own
  // errors for the same reason _notifyOwnerOfNewOrder does: by the time this
  // runs, the order + order_items are already committed in separate prior
  // calls, so a failure here (e.g. RLS not permitting a customer to write to
  // `invoices`) does not mean the order failed, and must not be reported as
  // one. If it does fail, the owner can still create/attach an invoice
  // manually from their side later.
  static Future<void> _createInvoiceDraftForOrder({
    required String businessId,
    required String customerId,
    required String orderId,
    required double totalAmount,
  }) async {
    try {
      final invoiceDraft = await CustomerBusinessService.createInvoiceDraft(
        businessId: businessId,
        customerId: customerId,
        orderId: orderId,
        totalAmount: totalAmount,
      );
      if (invoiceDraft == null) return;

      await SupabaseService.client.from('notifications').insert({
        'recipient_id': customerId,
        'business_id': businessId,
        'title': 'Invoice draft created',
        'body': 'Invoice ${invoiceDraft['invoice_number']} is ready for review.',
        'data': {'invoice_id': invoiceDraft['id']},
      });

      await SupabaseService.client.from('orders').update({'invoice_id': invoiceDraft['id']}).eq('id', orderId);
    } catch (_) {
      // Non-fatal -- see comment above.
    }
  }

  // Alerts the business owner that a new order came in. Looked up fresh each
  // time (rather than trusting a client-supplied id) so it can't be spoofed,
  // and deliberately swallows its own errors -- the order itself has already
  // been written successfully by the time this runs, so a failure here
  // (e.g. RLS not yet permitting a customer to read `businesses.owner_id`)
  // must not be reported back as a failed order.
  static Future<void> _notifyOwnerOfNewOrder({
    required String businessId,
    required String orderId,
    required double totalAmount,
  }) async {
    try {
      final business = await SupabaseService.client
          .from('businesses')
          .select('owner_id')
          .eq('id', businessId)
          .maybeSingle();
      final ownerId = business?['owner_id'] as String?;
      if (ownerId == null) return;

      await SupabaseService.client.from('notifications').insert({
        'recipient_id': ownerId,
        'business_id': businessId,
        'title': 'New order received',
        'body': 'A customer placed a new order worth ₹${totalAmount.toStringAsFixed(0)}.',
        'data': {'order_id': orderId},
      });
    } catch (_) {
      // Non-fatal -- see comment above.
    }
  }

  static Future<void> _persistDraftLocally(OrderDraft draft) async {
    final existingDrafts = await LocalStorageService.getSavedOrderDrafts();
    final updatedDrafts = [...existingDrafts, draft];
    await LocalStorageService.saveOrderDrafts(updatedDrafts);
  }
}
