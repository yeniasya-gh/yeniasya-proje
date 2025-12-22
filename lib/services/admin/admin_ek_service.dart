import '../hasura_manager.dart';

class AdminEkService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
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

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["ekler"] ?? []);
  }

  Future<bool> add({
    required String ad,
    String? aciklama,
    required double fiyat,
    required String pdfUrl,
    required String photoUrl,
    int? createdBy,
  }) async {
    const mutation = r'''
      mutation InsertEk(
        $ad: String!,
        $aciklama: String,
        $fiyat: numeric!,
        $pdf_url: String!,
        $photo_url: String!,
        $created_by: bigint
      ) {
        insert_ekler_one(object: {
          ad: $ad,
          aciklama: $aciklama,
          fiyat: $fiyat,
          pdf_url: $pdf_url,
          photo_url: $photo_url,
          created_by: $created_by
        }) { id }
      }
    ''';

    try {
      await _hasura.graphQLRequest(
        query: mutation,
        variables: {
          "ad": ad,
          "aciklama": aciklama,
          "fiyat": fiyat,
          "pdf_url": pdfUrl,
          "photo_url": photoUrl,
          "created_by": createdBy ?? 0,
        },
      );

      return true;
    } catch (e, s) {
      // ignore: avoid_print
      print("🔴 [AdminEkService] insert_ekler_one hata: $e");
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  Future<bool> update({
    required int id,
    required String ad,
    String? aciklama,
    required double fiyat,
    required String pdfUrl,
    required String photoUrl,
  }) async {
    const mutation = r'''
      mutation UpdateEk(
        $id: bigint!,
        $ad: String!,
        $aciklama: String,
        $fiyat: numeric!,
        $pdf_url: String!,
        $photo_url: String!
      ) {
        update_ekler_by_pk(
          pk_columns: {id: $id},
          _set: {
            ad: $ad,
            aciklama: $aciklama,
            fiyat: $fiyat,
            pdf_url: $pdf_url,
            photo_url: $photo_url
          }
        ) { id }
      }
    ''';

    try {
      await _hasura.graphQLRequest(
        query: mutation,
        variables: {
          "id": id,
          "ad": ad,
          "aciklama": aciklama,
          "fiyat": fiyat,
          "pdf_url": pdfUrl,
          "photo_url": photoUrl,
        },
      );
      return true;
    } catch (e, s) {
      // ignore: avoid_print
      print("🔴 [AdminEkService] update_ekler_by_pk hata: $e");
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    const mutation = r'''
      mutation DeleteEk($id: bigint!) {
        delete_ekler_by_pk(id: $id) { id }
      }
    ''';
    try {
      await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
      return true;
    } catch (e, s) {
      // ignore: avoid_print
      print("🔴 [AdminEkService] delete_ekler_by_pk hata: $e");
      // ignore: avoid_print
      print(s);
      rethrow;
    }
  }
}
