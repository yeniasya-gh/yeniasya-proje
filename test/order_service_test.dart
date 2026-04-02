import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/cdn_authenticated_client.dart';
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
    if (query.contains("orders(where") && !query.contains("orders_by_pk")) {
      return {
        "orders": [
          {
            "id": 10,
            "total_paid": 0,
            "status": "pending",
            "created_at": "2026-03-25T10:00:00.000Z",
            "payment_provider": "paratika",
          },
          {
            "id": 11,
            "total_paid": 149.5,
            "status": "paid",
            "created_at": "2026-03-25T11:00:00.000Z",
            "payment_provider": "paratika",
          },
        ],
      };
    }
    if (query.contains("orders_by_pk")) {
      return {
        "orders_by_pk": {
          "id": 77,
          "total_paid": 149.5,
          "status": "paid",
          "created_at": "2026-03-25T10:00:00.000Z",
          "payment_provider": "paratika",
          "delivery_address_id": 1,
          "billing_address_id": 2,
          "promo_code_id": null,
          "promo_code": null,
          "promo_discount_percent": null,
          "promo_discount_amount": null,
        },
        "order_items": [
          {
            "id": 1,
            "title": "Kitap",
            "quantity": 1,
            "unit_price": 149.5,
            "line_total": 149.5,
            "product_type": "book",
            "metadata": const {},
          },
        ],
      };
    }
    return const {};
  }
}

class _FakeCdnClient implements CdnAuthenticatedClient {
  _FakeCdnClient({required this.throw404OnDetail, this.orders});

  final bool throw404OnDetail;
  final List<Map<String, dynamic>>? orders;

  @override
  bool get hasToken => true;

  @override
  int? get currentUserId => 12;

  @override
  bool canReadUserScopedData(int userId) => true;

  @override
  bool shouldFallbackToHasura(Object error) => true;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) async {
    if (throw404OnDetail && path.contains("/auth/me/orders/77")) {
      throw CdnRequestException("Order not found.", statusCode: 404);
    }
    return {"ok": true, "data": orders ?? const []};
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

  test('OrderService.getOrderDetail falls back to Hasura on CDN 404', () async {
    final fakeHasura = _FakeHasuraManager();
    final fakeCdn = _FakeCdnClient(throw404OnDetail: true);
    final service = OrderService(hasura: fakeHasura, cdn: fakeCdn);

    final detail = await service.getOrderDetail(77);

    expect(detail, isNotNull);
    expect(detail?["id"], 77);
    expect(detail?["payment_provider"], "paratika");
    expect(fakeHasura.lastQuery, contains("orders_by_pk"));
  });

  test(
    'OrderService hides pending orders for user-facing lists by default',
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = OrderService(hasura: fakeHasura);

      final orders = await service.getOrders(12);

      expect(orders, hasLength(1));
      expect(orders.single["id"], 11);
      expect(orders.single["status"], "paid");
    },
  );

  test('OrderService keeps pending orders when explicitly requested', () async {
    final fakeCdn = _FakeCdnClient(
      throw404OnDetail: false,
      orders: [
        {
          "id": 10,
          "total_paid": 0,
          "status": "pending",
          "created_at": "2026-03-25T10:00:00.000Z",
          "payment_provider": "paratika",
          "order_items": const [],
        },
        {
          "id": 11,
          "total_paid": 149.5,
          "status": "paid",
          "created_at": "2026-03-25T11:00:00.000Z",
          "payment_provider": "paratika",
          "order_items": const [],
        },
      ],
    );
    final service = OrderService(cdn: fakeCdn);

    final orders = await service.getOrders(12, includePending: true);

    expect(orders, hasLength(2));
    expect(orders.first["status"], "pending");
    expect(orders.last["status"], "paid");
  });
}
