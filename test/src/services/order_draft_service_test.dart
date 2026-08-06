import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/src/models/order_draft.dart';
import 'package:hindustan_traders/src/services/order_draft_service.dart';

void main() {
  group('OrderDraftService.parseTranscript', () {
    test('extracts known grocery items from a spoken order', () {
      final draft = OrderDraftService.parseTranscript('Please send rice and milk today');

      expect(draft.transcript, 'Please send rice and milk today');
      expect(draft.items, containsAll(['Rice - 2 kg', 'Milk - 1 litre']));
    });

    test('returns a fallback item when no supported items are detected', () {
      final draft = OrderDraftService.parseTranscript('Need groceries for the house');

      expect(draft.items, ['No items detected']);
    });
  });

  group('OrderDraftService.estimateTotalAmount', () {
    test('sums the expected amount from detected items', () {
      final draft = const OrderDraft(transcript: 'rice milk', items: ['Rice - 2 kg', 'Milk - 1 litre']);

      expect(OrderDraftService.estimateTotalAmount(draft.items), 140);
    });
  });

  group('OrderDraftService.buildOrderItems', () {
    test('builds structured order items for persisted orders', () {
      final items = OrderDraftService.buildOrderItems(['Rice - 2 kg', 'Milk - 1 litre']);

      expect(items.map((item) => item.name), ['Rice', 'Milk']);
      expect(items.first.amount, 160);
      expect(items.last.amount, 60);
    });
  });

  group('OrderDraft serialization', () {
    test('preserves the created timestamp across JSON round-trips', () {
      final createdAt = DateTime(2026, 8, 5, 10, 30);
      final draft = OrderDraft(
        transcript: 'rice',
        items: ['Rice - 2 kg'],
        createdAt: createdAt,
      );

      final roundTrip = OrderDraft.fromJson(draft.toJson());

      expect(roundTrip.createdAt, equals(createdAt));
    });
  });
}
