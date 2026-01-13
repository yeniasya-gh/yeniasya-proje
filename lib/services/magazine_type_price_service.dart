import 'hasura_manager.dart';

class MagazineTypePriceService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getActiveByMagazine(int magazineId) async {
    const query = r'''
      query GetActiveMagazineTypePrices($magazine_id: Int!) {
        magazine_type_price(
          where: {
            magazine_id: {_eq: $magazine_id},
            is_active: {_eq: true}
          },
          order_by: {sort_order: asc, id: asc}
        ) {
          id
          magazine_type_id
          price
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
}
