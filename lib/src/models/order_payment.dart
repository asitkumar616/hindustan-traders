/// Payment method/status values for `orders.payment_method` /
/// `orders.payment_status` -- kept as plain string constants (matching the
/// check constraints added in the payment MVP migration) rather than a Dart
/// enum, so raw values read back from Supabase need no parsing/mapping step.
class OrderPaymentMethod {
  OrderPaymentMethod._();

  static const String upi = 'upi';
  static const String cashOnDelivery = 'cash_on_delivery';
}

class OrderPaymentStatus {
  OrderPaymentStatus._();

  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String failed = 'failed';
}
