import 'hasura_manager.dart';

class EkService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getEkler() async {
    const query = r'''
      query GetEkler {
        ekler(order_by: {created_at: desc}) {
          id
          ad
          aciklama
          fiyat
          pdf_url
          photo_url
          is_public
          created_at
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      timeout: HasuraManager.homeTimeout,
    );
    return List<Map<String, dynamic>>.from(data["ekler"] ?? []);
  }

  Future<Map<String, dynamic>?> getEk(int id) async {
    const query = r'''
      query GetEk($id: bigint!) {
        ekler_by_pk(id: $id) {
          id
          ad
          aciklama
          fiyat
          pdf_url
          photo_url
          is_public
          created_at
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(query: query, variables: {"id": id});
    return data["ekler_by_pk"] as Map<String, dynamic>?;
  }
}
