import 'hasura_manager.dart';

class NewspaperSubscriptionTypeService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getActiveTypes() async {
    const query = r'''
      query GetActiveNewspaperSubscriptionTypes {
        newspaper_subscription_type(
          where: {is_active: {_eq: true}},
          order_by: {sort_order: asc, id: asc}
        ) {
          id
          title
          duration_months
          price
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["newspaper_subscription_type"] ?? []);
  }
}
