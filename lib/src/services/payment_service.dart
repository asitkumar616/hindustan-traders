import 'supabase_service.dart';

/// Order-level payment reads/writes. Both mutating calls go through
/// SECURITY DEFINER RPCs (not raw `.update()`) -- the RPCs derive
/// business_id/customer ownership from the order row itself rather than
/// trusting client-supplied values, and owner_confirm_cod_payment is
/// idempotent (a second "Mark as Paid" tap on an already-paid order is a
/// no-op, guarding against double-confirmation).
class PaymentService {
  PaymentService._();

  static Future<void> setOrderPaymentMethod({
    required String orderId,
    required String paymentMethod,
  }) async {
    await SupabaseService.client.rpc('customer_set_order_payment_method', params: {
      'p_order_id': orderId,
      'p_payment_method': paymentMethod,
    });
  }

  static Future<void> confirmCodPayment(String orderId) async {
    await SupabaseService.client.rpc('owner_confirm_cod_payment', params: {
      'p_order_id': orderId,
    });
  }
}
