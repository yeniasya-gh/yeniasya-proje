import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/hasura_manager.dart';
import 'package:YeniAsya/services/order_service.dart';

class _FakeHasuraManager implements HasuraManager {
  String? lastQuery;
  Map<String, dynamic>? lastVariables;

  @override
  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    lastQuery = query;
    lastVariables = variables;
    if (query.contains("insert_orders_one")) {
      return {
        "insert_orders_one": {
          "id": 99,
          "total_paid": 149.5,
          "created_at": "2026-03-25T10:00:00.000Z",
          "promo_code": null,
          "promo_discount_percent": null,
          "promo_discount_amount": null,
          "payment_provider": "paratika",
        },
      };
    }
    if (query.contains("insert_order_items")) {
      return {
        "insert_order_items": {"affected_rows": 1},
      };
    }
    return const {};
  }
}

void main() {
  test('OrderService.createOrder sends payment provider', () async {
    final fakeHasura = _FakeHasuraManager();
    final service = OrderService(hasura: fakeHasura);

    final created = await service.createOrder(
      userId: "12",
      deliveryAddressId: 1,
      billingAddressId: 2,
      totalPaid: 149.5,
      items: const [],
      paymentProvider: "paratika",
    );

    expect(created["payment_provider"], "paratika");
    expect(fakeHasura.lastVariables?["payment_provider"], "paratika");
    expect(fakeHasura.lastQuery, contains("payment_provider"));
  });
}
