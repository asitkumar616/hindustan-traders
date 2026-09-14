/// Abstraction point for a real UPI payment gateway (Razorpay, Cashfree,
/// etc.), added now so the checkout screens can be built against a stable
/// interface without a rewrite once a gateway is actually integrated.
///
/// Deliberately NOT wired to any real gateway yet. The UPI option is shown
/// as disabled ("Coming soon") on the Payment Method screen, so this should
/// never actually be called from the UI today -- it exists as the seam a
/// future gateway integration plugs into, not as a working payment path.
/// Do not call this and treat its result as a real payment; there is no
/// gateway behind it yet.
class PaymentGatewayService {
  PaymentGatewayService._();

  static Future<UpiPaymentResult> initiateUpiPayment({
    required String orderId,
    required double amount,
  }) async {
    throw UnimplementedError(
      'No payment gateway is configured yet. UPI checkout is not available in this build.',
    );
  }
}

class UpiPaymentResult {
  final bool success;
  final String? referenceId;
  final String? failureReason;

  const UpiPaymentResult({
    required this.success,
    this.referenceId,
    this.failureReason,
  });
}
