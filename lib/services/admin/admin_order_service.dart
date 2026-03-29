import '../hasura_manager.dart';

bool _isMissingPaymentProviderColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("payment_provider") ||
      message.contains("merchant_payment_id") ||
      message.contains("payment_session_token");
}

class AdminOrderService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    const queryWithProvider = r'''
      query GetAllOrders {
        orders(order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
          payment_provider
          merchant_payment_id
          payment_session_token
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';
    const queryWithMerchantOnly = r'''
      query GetAllOrders {
        orders(order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
          merchant_payment_id
          payment_session_token
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';
    const queryWithoutChannel = r'''
      query GetAllOrders {
        orders(order_by: {created_at: desc}) {
          id
          total_paid
          status
          created_at
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(query: queryWithProvider);
    } catch (error) {
      if (!_isMissingPaymentProviderColumnError(error)) {
        rethrow;
      }
      try {
        data = await _hasura.graphQLRequest(query: queryWithMerchantOnly);
      } catch (merchantError) {
        if (!_isMissingPaymentProviderColumnError(merchantError)) {
          rethrow;
        }
        data = await _hasura.graphQLRequest(query: queryWithoutChannel);
      }
    }
    return List<Map<String, dynamic>>.from(data["orders"] ?? []);
  }
}
