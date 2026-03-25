import '../hasura_manager.dart';

bool _isMissingPaymentProviderColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("payment_provider");
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
          user_id
          user {
            id
            name
            email
          }
        }
      }
    ''';
    const queryWithoutProvider = r'''
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
      data = await _hasura.graphQLRequest(query: queryWithoutProvider);
    }
    return List<Map<String, dynamic>>.from(data["orders"] ?? []);
  }
}
