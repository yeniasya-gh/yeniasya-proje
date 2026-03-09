import '../hasura_manager.dart';

class AdminFaqService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    const query = r'''
      query GetFaqAdminList {
        faq(order_by: [{sort_order: asc}, {id: asc}]) {
          id
          title
          description
          sort_order
          is_active
          created_at
          updated_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["faq"] ?? const []);
  }

  Future<void> add({
    required String title,
    required String description,
    required int sortOrder,
    required bool isActive,
  }) async {
    const mutation = r'''
      mutation AddFaq(
        $title: String!,
        $description: String!,
        $sort_order: Int!,
        $is_active: Boolean!
      ) {
        insert_faq_one(object: {
          title: $title,
          description: $description,
          sort_order: $sort_order,
          is_active: $is_active
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "title": title,
        "description": description,
        "sort_order": sortOrder,
        "is_active": isActive,
      },
    );
  }

  Future<void> update({
    required int id,
    required String title,
    required String description,
    required int sortOrder,
    required bool isActive,
  }) async {
    const mutation = r'''
      mutation UpdateFaq(
        $id: Int!,
        $title: String!,
        $description: String!,
        $sort_order: Int!,
        $is_active: Boolean!
      ) {
        update_faq_by_pk(
          pk_columns: {id: $id},
          _set: {
            title: $title,
            description: $description,
            sort_order: $sort_order,
            is_active: $is_active
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "title": title,
        "description": description,
        "sort_order": sortOrder,
        "is_active": isActive,
      },
    );
  }

  Future<void> delete(int id) async {
    const mutation = r'''
      mutation DeleteFaq($id: Int!) {
        delete_faq_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }
}
