import 'order_status.dart';

class OrderDraft {
  final String transcript;
  final List<String> items;
  final OrderStatus status;
  final DateTime? createdAt;

  const OrderDraft({
    required this.transcript,
    required this.items,
    this.status = OrderStatus.incoming,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'transcript': transcript,
      'items': items,
      'status': status.name,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory OrderDraft.fromJson(Map<String, dynamic> json) {
    return OrderDraft(
      transcript: json['transcript'] as String? ?? '',
      items: List<String>.from(json['items'] ?? const []),
      status: OrderStatus.values.firstWhere(
        (value) => value.name == (json['status'] as String? ?? 'incoming'),
        orElse: () => OrderStatus.incoming,
      ),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }
}
