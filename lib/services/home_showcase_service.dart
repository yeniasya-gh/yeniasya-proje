import 'hasura_manager.dart';

class HomeShowcaseService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getByType(
    String type, {
    bool onlyActive = false,
  }) async {
    const baseQuery = r'''
      query GetHomeShowcase($type: String!) {
        home_showcase(
          where: {product_type: {_eq: $type}},
          order_by: {sort_order: asc, created_at: desc}
        ) {
          id
          product_type
          product_id
          sort_order
          is_active
          created_at
        }
      }
    ''';

    const activeQuery = r'''
      query GetHomeShowcase($type: String!) {
        home_showcase(
          where: {product_type: {_eq: $type}, is_active: {_eq: true}},
          order_by: {sort_order: asc, created_at: desc}
        ) {
          id
          product_type
          product_id
          sort_order
          is_active
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: onlyActive ? activeQuery : baseQuery,
      variables: {"type": type},
    );
    return List<Map<String, dynamic>>.from(data["home_showcase"] ?? []);
  }

  Future<bool> add({
    required String productType,
    required int productId,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    const mutation = r'''
      mutation AddHomeShowcase(
        $product_type: String!,
        $product_id: Int!,
        $sort_order: Int!,
        $is_active: Boolean!
      ) {
        insert_home_showcase_one(object: {
          product_type: $product_type,
          product_id: $product_id,
          sort_order: $sort_order,
          is_active: $is_active
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "product_type": productType,
        "product_id": productId,
        "sort_order": sortOrder,
        "is_active": isActive,
      },
    );
    return true;
  }

  Future<bool> updateSortOrder({
    required int id,
    required int sortOrder,
  }) async {
    const mutation = r'''
      mutation UpdateHomeShowcaseOrder($id: Int!, $sort_order: Int!) {
        update_home_showcase_by_pk(
          pk_columns: {id: $id},
          _set: {sort_order: $sort_order}
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id, "sort_order": sortOrder},
    );
    return true;
  }

  Future<bool> delete(int id) async {
    const mutation = r'''
      mutation DeleteHomeShowcase($id: Int!) {
        delete_home_showcase_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }
}
