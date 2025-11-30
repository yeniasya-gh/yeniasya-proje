import 'hasura_manager.dart';

class OrderService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getOrders(int userId) async {
    const query = r'''
      query GetOrders($user_id: bigint!) {
        orders(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"user_id": userId},
    );

    return List<Map<String, dynamic>>.from(data["orders"] ?? []);
  }

  Future<Map<String, dynamic>?> getOrderDetail(int id) async {
    const query = r'''
      query GetOrderDetail($id: bigint!) {
        orders_by_pk(id: $id) {
          id
          total_paid
          status
          created_at
          delivery_address_id
          billing_address_id
        }
        order_items(where: {order_id: {_eq: $id}}) {
          id
          title
          quantity
          unit_price
          line_total
          product_type
          metadata
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"id": id},
    );

    final order = data["orders_by_pk"] as Map<String, dynamic>?;
    if (order == null) return null;

    final items = List<Map<String, dynamic>>.from(data["order_items"] ?? []);
    return {
      ...order,
      "order_items": items,
    };
  }

  Future<Map<String, dynamic>> createOrder({
    required String userId,
    required int deliveryAddressId,
    required int billingAddressId,
    required double totalPaid,
    required List<Map<String, dynamic>> items,
  }) async {
    const createOrderMutation = r'''
      mutation CreateOrder(
        $user_id: bigint!,
        $delivery_address_id: bigint!,
        $billing_address_id: bigint!,
        $total_paid: numeric!
      ) {
        insert_orders_one(object: {
          user_id: $user_id,
          status: "paid",
          delivery_address_id: $delivery_address_id,
          billing_address_id: $billing_address_id,
          total_paid: $total_paid
        }) {
          id
          total_paid
          created_at
        }
      }
    ''';

    final orderData = await _hasura.graphQLRequest(
      query: createOrderMutation,
      variables: {
        "user_id": userId,
        "delivery_address_id": deliveryAddressId,
        "billing_address_id": billingAddressId,
        "total_paid": totalPaid,
      },
    );

    final createdOrder = Map<String, dynamic>.from(orderData["insert_orders_one"] ?? {});
    final orderId = createdOrder["id"];

    if (orderId != null && items.isNotEmpty) {
      const insertItemsMutation = r'''
        mutation InsertItems($items: [order_items_insert_input!]!) {
          insert_order_items(objects: $items) { affected_rows }
        }
      ''';

      final itemsWithOrder = items
          .map((i) => {
                ...i,
                "order_id": orderId,
              })
          .toList();

      await _hasura.graphQLRequest(
        query: insertItemsMutation,
        variables: {"items": itemsWithOrder},
      );
    }

    return createdOrder;
  }
}
