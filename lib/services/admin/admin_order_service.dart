import '../hasura_manager.dart';

class AdminOrderService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    const query = r'''
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

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["orders"] ?? []);
  }
}
