import '../hasura_manager.dart';

class AdminNewspaperService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    const query = r'''
      query GetNewspapers {
        newspaper(order_by: {publish_date: desc}) {
          id
          image_url
          publish_date
          file_url
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["newspaper"]);
  }

  Future<bool> add({
    required String imageUrl,
    required String fileUrl,
    required String publishDate,
  }) async {
    const mutation = r'''
      mutation AddNewspaper(
        $image_url: String!,
        $file_url: String!,
        $publish_date: date!
      ) {
        insert_newspaper_one(object: {
          image_url: $image_url,
          file_url: $file_url,
          publish_date: $publish_date
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "image_url": imageUrl,
        "file_url": fileUrl,
        "publish_date": publishDate,
      },
    );

    return true;
  }

  Future<bool> update({
    required int id,
    required String imageUrl,
    required String fileUrl,
    required String publishDate,
  }) async {
    const mutation = r'''
      mutation UpdateNewspaper(
        $id: Int!,
        $image_url: String!,
        $file_url: String!,
        $publish_date: date!
      ) {
        update_newspaper_by_pk(
          pk_columns: {id: $id},
          _set: {
            image_url: $image_url,
            file_url: $file_url,
            publish_date: $publish_date
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "image_url": imageUrl,
        "file_url": fileUrl,
        "publish_date": publishDate,
      },
    );

    return true;
  }

  Future<bool> delete(int id) async {
    const mutation = r'''
      mutation DeleteNewspaper($id: Int!) {
        delete_newspaper_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }
}
