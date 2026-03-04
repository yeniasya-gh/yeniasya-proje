import '../hasura_manager.dart';

class AdminManualNewspaperUserService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> listManualUsers() async {
    const query = r'''
      query ListManualNewspaperUsers {
        manual_newspaper_users(
          order_by: [{is_active: desc}, {ends_at: asc}, {id: desc}]
        ) {
          id
          user_id
          starts_at
          ends_at
          is_active
          note
          created_at
          updated_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    final rows = List<Map<String, dynamic>>.from(
      data["manual_newspaper_users"] ?? [],
    );
    if (rows.isEmpty) return rows;

    final userIds = rows
        .map((e) => e["user_id"])
        .where((v) => v != null)
        .map((v) => v.toString())
        .toSet()
        .toList();
    if (userIds.isEmpty) return rows;

    const usersQuery = r'''
      query GetManualNewspaperUsersByIds($ids: [bigint!]!) {
        users(where: {id: {_in: $ids}}) {
          id
          name
          email
        }
      }
    ''';
    final usersData = await _hasura.graphQLRequest(
      query: usersQuery,
      variables: {"ids": userIds},
    );
    final users = List<Map<String, dynamic>>.from(usersData["users"] ?? []);
    final usersById = <String, Map<String, dynamic>>{
      for (final u in users) u["id"].toString(): u,
    };

    return rows
        .map(
          (row) => {
            ...row,
            "user":
                usersById[row["user_id"]?.toString()] ??
                {
                  "id": row["user_id"],
                  "name": "Kullanıcı #${row["user_id"]}",
                  "email": "-",
                },
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchUsers({
    required String keyword,
    int limit = 20,
  }) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      const query = r'''
        query SearchManualUsersFallback($limit: Int!) {
          users(order_by: {id: desc}, limit: $limit) {
            id
            name
            email
          }
        }
      ''';
      final data = await _hasura.graphQLRequest(
        query: query,
        variables: {"limit": limit},
      );
      return List<Map<String, dynamic>>.from(data["users"] ?? []);
    }

    const query = r'''
      query SearchManualUsers($keyword: String!, $limit: Int!) {
        users(
          where: {
            _or: [
              {name: {_ilike: $keyword}},
              {email: {_ilike: $keyword}}
            ]
          },
          order_by: {id: desc},
          limit: $limit
        ) {
          id
          name
          email
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"keyword": "%$normalized%", "limit": limit},
    );
    return List<Map<String, dynamic>>.from(data["users"] ?? []);
  }

  Future<void> upsertManualUser({
    required int userId,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
    String? note,
  }) async {
    const mutation = r'''
      mutation UpsertManualNewspaperUser($object: manual_newspaper_users_insert_input!) {
        insert_manual_newspaper_users_one(
          object: $object,
          on_conflict: {
            constraint: manual_newspaper_users_user_id_key,
            update_columns: [starts_at, ends_at, is_active, note, updated_at]
          }
        ) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "object": {
          "user_id": userId.toString(),
          "starts_at": startsAt.toUtc().toIso8601String(),
          "ends_at": endsAt.toUtc().toIso8601String(),
          "is_active": isActive,
          "note": (note ?? "").trim().isEmpty ? null : note!.trim(),
          "updated_at": DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
  }

  Future<void> updateById({
    required int id,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
    String? note,
  }) async {
    const mutation = r'''
      mutation UpdateManualNewspaperUser($id: bigint!, $_set: manual_newspaper_users_set_input!) {
        update_manual_newspaper_users_by_pk(
          pk_columns: {id: $id},
          _set: $_set
        ) {
          id
        }
      }
    ''';

    final set = <String, dynamic>{
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    };
    if (startsAt != null) {
      set["starts_at"] = startsAt.toUtc().toIso8601String();
    }
    if (endsAt != null) {
      set["ends_at"] = endsAt.toUtc().toIso8601String();
    }
    if (isActive != null) {
      set["is_active"] = isActive;
    }
    if (note != null) {
      set["note"] = note.trim().isEmpty ? null : note.trim();
    }

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id.toString(), "_set": set},
    );
  }

  Future<void> deleteById(int id) async {
    const mutation = r'''
      mutation DeleteManualNewspaperUser($id: bigint!) {
        delete_manual_newspaper_users_by_pk(id: $id) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id.toString()},
    );
  }
}
