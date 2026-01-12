import '../hasura_manager.dart';

class AdminNewspaperSubscriptionTypeService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    const query = r'''
      query GetNewspaperSubscriptionTypes {
        newspaper_subscription_type(order_by: {sort_order: asc, id: desc}) {
          id
          title
          duration_months
          price
          is_active
          sort_order
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["newspaper_subscription_type"] ?? []);
  }

  Future<void> create({
    required String title,
    required int durationMonths,
    required double price,
    required bool isActive,
    required int sortOrder,
  }) async {
    const mutation = r'''
      mutation CreateNewspaperSubscriptionType(
        $title: String!,
        $duration_months: Int!,
        $price: numeric!,
        $is_active: Boolean!,
        $sort_order: Int!
      ) {
        insert_newspaper_subscription_type_one(object: {
          title: $title,
          duration_months: $duration_months,
          price: $price,
          is_active: $is_active,
          sort_order: $sort_order
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "title": title,
        "duration_months": durationMonths,
        "price": price,
        "is_active": isActive,
        "sort_order": sortOrder,
      },
    );
  }

  Future<void> update({
    required int id,
    required String title,
    required int durationMonths,
    required double price,
    required bool isActive,
    required int sortOrder,
  }) async {
    const mutation = r'''
      mutation UpdateNewspaperSubscriptionType(
        $id: Int!,
        $title: String!,
        $duration_months: Int!,
        $price: numeric!,
        $is_active: Boolean!,
        $sort_order: Int!
      ) {
        update_newspaper_subscription_type_by_pk(
          pk_columns: {id: $id},
          _set: {
            title: $title,
            duration_months: $duration_months,
            price: $price,
            is_active: $is_active,
            sort_order: $sort_order
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "title": title,
        "duration_months": durationMonths,
        "price": price,
        "is_active": isActive,
        "sort_order": sortOrder,
      },
    );
  }

  Future<void> delete(int id) async {
    const mutation = r'''
      mutation DeleteNewspaperSubscriptionType($id: bigint!) {
        delete_newspaper_subscription_type_by_pk(id: $id) { id }
      }
    ''';
    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }
}
