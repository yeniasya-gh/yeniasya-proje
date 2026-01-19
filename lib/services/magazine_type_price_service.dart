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
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"magazine_id": magazineId},
    );
    final prices = List<Map<String, dynamic>>.from(data["magazine_type_price"] ?? []);
    final typeIds = prices
        .map((item) => int.tryParse(item["magazine_type_id"]?.toString() ?? ""))
        .whereType<int>()
        .toSet()
        .toList();
    if (typeIds.isEmpty) return prices;

    const typeQuery = r'''
      query GetMagazineTypesByIds($ids: [Int!]!) {
        magazine_type(where: {id: {_in: $ids}}) {
          id
          title
          duration_months
        }
      }
    ''';
    final typeData = await _hasura.graphQLRequest(
      query: typeQuery,
      variables: {"ids": typeIds},
    );
    final types = List<Map<String, dynamic>>.from(typeData["magazine_type"] ?? []);
    final typeById = {
      for (final t in types)
        int.tryParse(t["id"]?.toString() ?? "") ?? -1: t,
    };
    for (final item in prices) {
      final id = int.tryParse(item["magazine_type_id"]?.toString() ?? "") ?? -1;
      item["magazine_type"] = typeById[id] ?? {};
    }
    return prices;
  }
}
