import 'hasura_manager.dart';

class FaqService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getActiveFaqs() async {
    const query = r'''
      query GetActiveFaqs {
        faq(
          where: {is_active: {_eq: true}},
          order_by: [{sort_order: asc}, {id: asc}]
        ) {
          id
          title
          description
          sort_order
          is_active
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["faq"] ?? const []);
  }
}
