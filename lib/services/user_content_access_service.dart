import 'hasura_manager.dart';

class UserContentAccessService {
  final _hasura = HasuraManager.instance;

  Future<void> grantAccess({
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return;

    final parsedUserId = int.tryParse(userId);
    if (parsedUserId == null) {
      throw Exception("Geçersiz kullanıcı ID");
    }

    const mutation = r'''
      mutation InsertAccess($items: [user_content_access_insert_input!]!) {
        insert_user_content_access(objects: $items) {
          affected_rows
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "items": items
            .map((i) => {
                  "user_id": parsedUserId,
                  "item_type": i["item_type"],
                  "item_id": i["item_id"],
                  "is_active": true,
                  "started_at": i["started_at"],
                  "expires_at": i["expires_at"],
                  "purchase_price": i["purchase_price"],
                })
            .toList(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAccess({
    required int userId,
    required String itemType,
  }) async {
    const query = r'''
      query GetAccess($user_id: Int!, $item_type: access_item_type!) {
        user_content_access(
          where: {
            user_id: {_eq: $user_id},
            item_type: {_eq: $item_type},
            is_active: {_eq: true}
          }
          order_by: {started_at: desc}
        ) {
          id
          item_id
          item_type
          expires_at
          started_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"user_id": userId, "item_type": itemType},
    );

    return List<Map<String, dynamic>>.from(data["user_content_access"] ?? []);
  }

  Future<List<Map<String, dynamic>>> getAll({
    required int userId,
  }) async {
    const query = r'''
      query GetAccessAll($user_id: Int!) {
        user_content_access(
          where: {user_id: {_eq: $user_id}, is_active: {_eq: true}},
          order_by: {started_at: desc}
        ) {
          id
          item_id
          item_type
          expires_at
          started_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"user_id": userId},
    );

    return List<Map<String, dynamic>>.from(data["user_content_access"] ?? []);
  }
}
