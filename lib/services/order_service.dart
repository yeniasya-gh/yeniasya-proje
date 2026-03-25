import 'hasura_manager.dart';
import 'cdn_authenticated_client.dart';

bool _isMissingPaymentProviderColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("payment_provider");
}

class OrderService {
  OrderService({HasuraManager? hasura, CdnAuthenticatedClient? cdn})
    : _hasura = hasura ?? HasuraManager.instance,
      _cdn = cdn ?? CdnAuthenticatedClient();

  final HasuraManager _hasura;
  final CdnAuthenticatedClient _cdn;

  Future<List<Map<String, dynamic>>> getOrders(int userId) async {
    if (_cdn.canReadUserScopedData(userId)) {
      try {
        return await _getOrdersFromCdn();
      } catch (error) {
        if (!_cdn.shouldFallbackToHasura(error)) {
          rethrow;
        }
      }
    }

    return _getOrdersFromHasura(userId);
  }

  Future<List<Map<String, dynamic>>> _getOrdersFromHasura(int userId) async {
    const queryWithProvider = r'''
      query GetOrders($user_id: bigint!) {
        orders(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
          id
          total_paid
          status
          payment_provider
          promo_code_id
          promo_code
          promo_discount_percent
          promo_discount_amount
          created_at
        }
      }
    ''';
    const queryWithoutProvider = r'''
      query GetOrders($user_id: bigint!) {
        orders(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
          id
          total_paid
          status
          promo_code_id
          promo_code
          promo_discount_percent
          promo_discount_amount
          created_at
        }
      }
    ''';

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(
        query: queryWithProvider,
        variables: {"user_id": userId},
      );
    } catch (error) {
      if (!_isMissingPaymentProviderColumnError(error)) {
        rethrow;
      }
      data = await _hasura.graphQLRequest(
        query: queryWithoutProvider,
        variables: {"user_id": userId},
      );
    }

    return List<Map<String, dynamic>>.from(data["orders"] ?? []);
  }

  Future<List<Map<String, dynamic>>> getOrdersWithItems(int userId) async {
    if (_cdn.canReadUserScopedData(userId)) {
      try {
        return await _getOrdersFromCdn(includeItems: true);
      } catch (error) {
        if (!_cdn.shouldFallbackToHasura(error)) {
          rethrow;
        }
      }
    }

    final orders = await _getOrdersFromHasura(userId);
    if (orders.isEmpty) return [];

    final ids = orders.map((o) => o["id"]).whereType<int>().toList();
    if (ids.isEmpty) return orders;

    const itemsQuery = r'''
      query GetOrderItems($order_ids: [bigint!]!) {
        order_items(where: {order_id: {_in: $order_ids}}) {
          id
          order_id
          title
          quantity
          unit_price
          line_total
          product_type
          metadata
        }
      }
    ''';

    final itemsData = await _hasura.graphQLRequest(
      query: itemsQuery,
      variables: {"order_ids": ids},
    );

    final items = List<Map<String, dynamic>>.from(
      itemsData["order_items"] ?? [],
    );
    final byOrder = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final oid = item["order_id"] as int?;
      if (oid == null) continue;
      byOrder.putIfAbsent(oid, () => []).add(item);
    }

    return orders
        .map(
          (o) => {
            ...o,
            "order_items": byOrder[o["id"]] ?? <Map<String, dynamic>>[],
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getOrderDetail(int id) async {
    if (_cdn.hasToken) {
      try {
        return await _getOrderDetailFromCdn(id);
      } catch (error) {
        if (!_cdn.shouldFallbackToHasura(error)) {
          rethrow;
        }
      }
    }

    return _getOrderDetailFromHasura(id);
  }

  Future<Map<String, dynamic>?> _getOrderDetailFromHasura(int id) async {
    const queryWithProvider = r'''
      query GetOrderDetail($id: bigint!) {
        orders_by_pk(id: $id) {
          id
          total_paid
          status
          created_at
          payment_provider
          delivery_address_id
          billing_address_id
          promo_code_id
          promo_code
          promo_discount_percent
          promo_discount_amount
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
    const queryWithoutProvider = r'''
      query GetOrderDetail($id: bigint!) {
        orders_by_pk(id: $id) {
          id
          total_paid
          status
          created_at
          delivery_address_id
          billing_address_id
          promo_code_id
          promo_code
          promo_discount_percent
          promo_discount_amount
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

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(
        query: queryWithProvider,
        variables: {"id": id},
      );
    } catch (error) {
      if (!_isMissingPaymentProviderColumnError(error)) {
        rethrow;
      }
      data = await _hasura.graphQLRequest(
        query: queryWithoutProvider,
        variables: {"id": id},
      );
    }

    final order = data["orders_by_pk"] as Map<String, dynamic>?;
    if (order == null) return null;

    final items = List<Map<String, dynamic>>.from(data["order_items"] ?? []);
    return {...order, "order_items": items};
  }

  Future<List<Map<String, dynamic>>> _getOrdersFromCdn({
    bool includeItems = false,
  }) async {
    final data = await _cdn.getJson(
      "/auth/me/orders",
      queryParameters: {if (includeItems) "includeItems": "true"},
    );
    return List<Map<String, dynamic>>.from(data["data"] ?? const []);
  }

  Future<Map<String, dynamic>?> _getOrderDetailFromCdn(int id) async {
    final data = await _cdn.getJson("/auth/me/orders/$id");
    final order = data["order"];
    if (order is! Map) return null;
    return Map<String, dynamic>.from(order);
  }

  Future<Map<String, dynamic>> createOrder({
    required String userId,
    required int deliveryAddressId,
    required int billingAddressId,
    required double totalPaid,
    required List<Map<String, dynamic>> items,
    String status = "paid",
    int? promoCodeId,
    String? promoCode,
    double? promoDiscountPercent,
    double? promoDiscountAmount,
    String? merchantPaymentId,
    String? paymentSessionToken,
    bool? paymentApproved,
    String? paymentProvider,
    String? paymentResponseCode,
    String? paymentResponseMsg,
    String? paymentErrorCode,
    String? paymentErrorMsg,
  }) async {
    const createOrderMutationWithProvider = r'''
      mutation CreateOrder(
        $user_id: bigint!,
        $delivery_address_id: bigint!,
        $billing_address_id: bigint!,
        $total_paid: numeric!,
        $status: order_status!,
        $promo_code_id: bigint,
        $promo_code: String,
        $promo_discount_percent: numeric,
        $promo_discount_amount: numeric,
        $payment_provider: String,
        $merchant_payment_id: String,
        $payment_session_token: String,
        $payment_approved: Boolean,
        $payment_response_code: String,
        $payment_response_msg: String,
        $payment_error_code: String,
        $payment_error_msg: String
      ) {
        insert_orders_one(object: {
          user_id: $user_id,
          status: $status,
          delivery_address_id: $delivery_address_id,
          billing_address_id: $billing_address_id,
          total_paid: $total_paid,
          promo_code_id: $promo_code_id,
          promo_code: $promo_code,
          promo_discount_percent: $promo_discount_percent,
          promo_discount_amount: $promo_discount_amount,
          payment_provider: $payment_provider,
          merchant_payment_id: $merchant_payment_id,
          payment_session_token: $payment_session_token,
          payment_approved: $payment_approved,
          payment_response_code: $payment_response_code,
          payment_response_msg: $payment_response_msg,
          payment_error_code: $payment_error_code,
          payment_error_msg: $payment_error_msg
        }) {
          id
          total_paid
          created_at
          promo_code
          promo_discount_percent
          promo_discount_amount
          payment_provider
        }
      }
    ''';
    const createOrderMutationWithoutProvider = r'''
      mutation CreateOrder(
        $user_id: bigint!,
        $delivery_address_id: bigint!,
        $billing_address_id: bigint!,
        $total_paid: numeric!,
        $status: order_status!,
        $promo_code_id: bigint,
        $promo_code: String,
        $promo_discount_percent: numeric,
        $promo_discount_amount: numeric,
        $merchant_payment_id: String,
        $payment_session_token: String,
        $payment_approved: Boolean,
        $payment_response_code: String,
        $payment_response_msg: String,
        $payment_error_code: String,
        $payment_error_msg: String
      ) {
        insert_orders_one(object: {
          user_id: $user_id,
          status: $status,
          delivery_address_id: $delivery_address_id,
          billing_address_id: $billing_address_id,
          total_paid: $total_paid,
          promo_code_id: $promo_code_id,
          promo_code: $promo_code,
          promo_discount_percent: $promo_discount_percent,
          promo_discount_amount: $promo_discount_amount,
          merchant_payment_id: $merchant_payment_id,
          payment_session_token: $payment_session_token,
          payment_approved: $payment_approved,
          payment_response_code: $payment_response_code,
          payment_response_msg: $payment_response_msg,
          payment_error_code: $payment_error_code,
          payment_error_msg: $payment_error_msg
        }) {
          id
          total_paid
          created_at
          promo_code
          promo_discount_percent
          promo_discount_amount
        }
      }
    ''';

    final orderData = await _createOrderWithFallback(
      variables: {
        "user_id": userId,
        "delivery_address_id": deliveryAddressId,
        "billing_address_id": billingAddressId,
        "total_paid": totalPaid,
        "status": status,
        "promo_code_id": promoCodeId,
        "promo_code": promoCode,
        "promo_discount_percent": promoDiscountPercent,
        "promo_discount_amount": promoDiscountAmount,
        "payment_provider": paymentProvider,
        "merchant_payment_id": merchantPaymentId,
        "payment_session_token": paymentSessionToken,
        "payment_approved": paymentApproved,
        "payment_response_code": paymentResponseCode,
        "payment_response_msg": paymentResponseMsg,
        "payment_error_code": paymentErrorCode,
        "payment_error_msg": paymentErrorMsg,
      },
      withProviderQuery: createOrderMutationWithProvider,
      withoutProviderQuery: createOrderMutationWithoutProvider,
    );

    final createdOrder = Map<String, dynamic>.from(
      orderData["insert_orders_one"] ?? {},
    );
    final orderId = createdOrder["id"];

    if (orderId != null && items.isNotEmpty) {
      const insertItemsMutation = r'''
        mutation InsertItems($items: [order_items_insert_input!]!) {
          insert_order_items(objects: $items) { affected_rows }
        }
      ''';

      final itemsWithOrder = items
          .map((i) => {...i, "order_id": orderId})
          .toList();

      await _hasura.graphQLRequest(
        query: insertItemsMutation,
        variables: {"items": itemsWithOrder},
      );
    }

    return createdOrder;
  }

  Future<Map<String, dynamic>> _createOrderWithFallback({
    required Map<String, dynamic> variables,
    required String withProviderQuery,
    required String withoutProviderQuery,
  }) async {
    try {
      return await _hasura.graphQLRequest(
        query: withProviderQuery,
        variables: variables,
      );
    } catch (error) {
      if (!_isMissingPaymentProviderColumnError(error)) {
        rethrow;
      }
      final fallbackVariables = Map<String, dynamic>.from(variables)
        ..remove("payment_provider");
      return await _hasura.graphQLRequest(
        query: withoutProviderQuery,
        variables: fallbackVariables,
      );
    }
  }

  Future<void> updateOrderPaymentStatus({
    required int orderId,
    required String status,
    bool? paymentApproved,
    String? paymentResponseCode,
    String? paymentResponseMsg,
    String? paymentErrorCode,
    String? paymentErrorMsg,
  }) async {
    const mutation = r'''
      mutation UpdateOrderPayment(
        $id: bigint!,
        $status: order_status!,
        $payment_approved: Boolean,
        $payment_response_code: String,
        $payment_response_msg: String,
        $payment_error_code: String,
        $payment_error_msg: String
      ) {
        update_orders_by_pk(
          pk_columns: {id: $id},
          _set: {
            status: $status,
            payment_approved: $payment_approved,
            payment_response_code: $payment_response_code,
            payment_response_msg: $payment_response_msg,
            payment_error_code: $payment_error_code,
            payment_error_msg: $payment_error_msg
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": orderId,
        "status": status,
        "payment_approved": paymentApproved,
        "payment_response_code": paymentResponseCode,
        "payment_response_msg": paymentResponseMsg,
        "payment_error_code": paymentErrorCode,
        "payment_error_msg": paymentErrorMsg,
      },
    );
  }
}

class ContactService {
  final _hasura = HasuraManager.instance;

  Future<bool> sendContact({
    required String subject,
    required String message,
    int? userId,
    String? email,
  }) async {
    const mutation = r'''
      mutation InsertContact(
        $subject: String!,
        $message: String!,
        $user_id: bigint,
        $email: String
      ) {
        insert_contact_messages_one(object: {
          subject: $subject,
          message: $message,
          user_id: $user_id,
          email: $email
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "subject": subject,
        "message": message,
        "user_id": userId,
        "email": email,
      },
    );
    return true;
  }
}
