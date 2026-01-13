import '../hasura_manager.dart';

class AdminMagazineTypePriceService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getByMagazine(int magazineId) async {
    const query = r'''
      query GetMagazineTypePrices($magazine_id: Int!) {
        magazine_type_price(
          where: {magazine_id: {_eq: $magazine_id}},
          order_by: {sort_order: asc, id: asc}
        ) {
          id
          magazine_id
          magazine_type_id
          price
          is_active
          sort_order
          magazine_type {
            id
            title
            duration_months
          }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"magazine_id": magazineId},
    );
    return List<Map<String, dynamic>>.from(data["magazine_type_price"] ?? []);
  }

  Future<void> replacePrices({
    required int magazineId,
    required List<Map<String, dynamic>> prices,
  }) async {
    const deleteMutation = r'''
      mutation DeleteMagazineTypePrices($magazine_id: Int!) {
        delete_magazine_type_price(where: {magazine_id: {_eq: $magazine_id}}) {
          affected_rows
        }
      }
    ''';

    const insertMutation = r'''
      mutation InsertMagazineTypePrices($items: [magazine_type_price_insert_input!]!) {
        insert_magazine_type_price(objects: $items) {
          affected_rows
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: deleteMutation,
      variables: {"magazine_id": magazineId},
    );

    if (prices.isEmpty) return;
    await _hasura.graphQLRequest(
      query: insertMutation,
      variables: {"items": prices},
    );
  }
}
