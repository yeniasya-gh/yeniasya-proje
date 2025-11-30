import '../hasura_manager.dart';

class AdminAuthorService {
  final _hasura = HasuraManager.instance;

  /// TÜM YAZARLARI GETİR
  Future<List<Map<String, dynamic>>> getAllAuthors() async {
    const query = r'''
      query GetAuthors {
        authors(order_by: {id: asc}) {
          id
          name
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["authors"]);
  }

  /// EKLE
  Future<bool> addAuthor(String name) async {
    const mutation = r'''
      mutation AddAuthor($name: String!) {
        insert_authors_one(object: { name: $name }) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "name": name,
    });

    return true;
  }

  /// GÜNCELLE
  Future<bool> updateAuthor(int id, String name) async {
    const mutation = r'''
      mutation UpdateAuthor($id: Int!, $name: String!) {
        update_authors_by_pk(pk_columns: {id: $id}, _set: {name: $name}) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "id": id,
      "name": name,
    });

    return true;
  }

  /// SİL
  Future<bool> deleteAuthor(int id) async {
    const mutation = r'''
      mutation DeleteAuthor($id: Int!) {
        delete_authors_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "id": id,
    });

    return true;
  }
}