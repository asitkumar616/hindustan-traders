import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hindustan_traders/src/models/order_draft.dart';
import 'package:hindustan_traders/src/models/order_status.dart';
import 'package:hindustan_traders/src/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('updates the matching draft when the owner changes its status', () async {
    final first = const OrderDraft(
      transcript: 'rice',
      items: ['Rice - 2 kg'],
      status: OrderStatus.incoming,
    );
    final second = const OrderDraft(
      transcript: 'milk',
      items: ['Milk - 1 litre'],
      status: OrderStatus.incoming,
    );

    await LocalStorageService.saveOrderDrafts([first, second]);
    await LocalStorageService.updateOrderDraftStatus(second, OrderStatus.ready);

    final drafts = await LocalStorageService.getSavedOrderDrafts();

    expect(drafts[0].status, OrderStatus.incoming);
    expect(drafts[1].status, OrderStatus.ready);
  });
}
