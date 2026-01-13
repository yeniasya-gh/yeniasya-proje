import '../hasura_manager.dart';

class AdminMagazineTypeService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    const query = r'''
      query GetMagazineTypes {
        magazine_type(order_by: {sort_order: asc, id: asc}) {
          id
          title
          duration_months
          is_active
          sort_order
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["magazine_type"] ?? []);
  }

  Future<void> create({
    required String title,
    required int durationMonths,
    required bool isActive,
    required int sortOrder,
  }) async {
    const mutation = r'''
      mutation CreateMagazineType(
        $title: String!,
        $duration_months: Int!,
        $is_active: Boolean!,
        $sort_order: Int!
      ) {
        insert_magazine_type_one(object: {
          title: $title,
          duration_months: $duration_months,
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
        "is_active": isActive,
        "sort_order": sortOrder,
      },
    );
  }

  Future<void> update({
    required int id,
    required String title,
    required int durationMonths,
    required bool isActive,
    required int sortOrder,
  }) async {
    const mutation = r'''
      mutation UpdateMagazineType(
        $id: Int!,
        $title: String!,
        $duration_months: Int!,
        $is_active: Boolean!,
        $sort_order: Int!
      ) {
        update_magazine_type_by_pk(
          pk_columns: {id: $id},
          _set: {
            title: $title,
            duration_months: $duration_months,
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
        "is_active": isActive,
        "sort_order": sortOrder,
      },
    );
  }

  Future<void> delete(int id) async {
    const mutation = r'''
      mutation DeleteMagazineType($id: Int!) {
        delete_magazine_type_by_pk(id: $id) { id }
      }
    ''';
    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }
}
