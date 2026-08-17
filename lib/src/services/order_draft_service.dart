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
            'product_id': item['product_id'] ?? null,
            'quantity': item['quantity'],
            'unit': item['unit'],
            'price': item['price'],
            'amount': item['amount'],
          }).toList(),
        );

        final invoiceDraft = await CustomerBusinessService.createInvoiceDraft(
          businessId: resolvedBusinessId,
          customerId: user.id,
          orderId: orderId,
          totalAmount: mappedProducts.fold<double>(0, (sum, current) => sum + (current['amount'] as num).toDouble()),
        );
        if (invoiceDraft != null) {
          await SupabaseService.client.from('notifications').insert({
            'recipient_id': user.id,
            'business_id': resolvedBusinessId,
            'title': 'Invoice draft created',
            'body': 'Invoice ${invoiceDraft['invoice_number']} is ready for review.',
            'data': {'invoice_id': invoiceDraft['id']},
          });

          await SupabaseService.client.from('orders').update({'invoice_id': invoiceDraft['id']}).eq('id', orderId);
        }
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

  static Future<void> _persistDraftLocally(OrderDraft draft) async {
    final existingDrafts = await LocalStorageService.getSavedOrderDrafts();
    final updatedDrafts = [...existingDrafts, draft];
    await LocalStorageService.saveOrderDrafts(updatedDrafts);
  }
}
