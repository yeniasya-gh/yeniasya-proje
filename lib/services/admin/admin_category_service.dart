import '../hasura_manager.dart';

class AdminCategoryService {
  final _hasura = HasuraManager.instance;

  /// TÜM KATEGORİLER
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    const query = r'''
      query GetCategories {
        categories(order_by: {id: asc}) {
          id
          name
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["categories"]);
  }

  /// EKLE
  Future<bool> addCategory(String name) async {
    const mutation = r'''
      mutation AddCategory($name: String!) {
        insert_categories_one(object: { name: $name }) {
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
  Future<bool> updateCategory(int id, String name) async {
    const mutation = r'''
      mutation UpdateCategory($id: Int!, $name: String!) {
        update_categories_by_pk(pk_columns: {id: $id}, _set: {name: $name}) {
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
  Future<bool> deleteCategory(int id) async {
    const mutation = r'''
      mutation DeleteCategory($id: Int!) {
        delete_categories_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "id": id,
    });

    return true;
  }
}