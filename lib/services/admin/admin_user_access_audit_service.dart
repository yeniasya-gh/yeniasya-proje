import '../hasura_manager.dart';

class AdminUserAccessAuditService {
  final _hasura = HasuraManager.instance;

  Future<void> logEntry({
    required int userId,
    required String action,
    required String itemType,
    int? itemId,
    String? itemTitle,
    String? accessSource,
    DateTime? previousExpiresAt,
    DateTime? newExpiresAt,
    String? note,
    int? actorUserId,
  }) async {
    const mutation = r'''
      mutation InsertUserAccessAuditLog(
        $object: user_access_audit_log_insert_input!
      ) {
        insert_user_access_audit_log_one(object: $object) {
          id
        }
      }
    ''';

    try {
      await _hasura.graphQLRequest(
        query: mutation,
        variables: {
          "object": {
            "user_id": userId.toString(),
            "actor_user_id": actorUserId?.toString(),
            "action": action,
            "item_type": itemType,
            "item_id": itemId,
            "item_title": _normalizedText(itemTitle),
            "access_source": _normalizedText(accessSource),
            "previous_expires_at": previousExpiresAt?.toUtc().toIso8601String(),
            "new_expires_at": newExpiresAt?.toUtc().toIso8601String(),
            "note": _normalizedText(note),
          },
        },
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("user_access_audit_log")) {
        return;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listForUser(int userId, {int limit = 20}) async {
    const query = r'''
      query GetUserAccessAuditLog($user_id: bigint!, $limit: Int!) {
        user_access_audit_log(
          where: {user_id: {_eq: $user_id}},
          order_by: [{created_at: desc}, {id: desc}],
          limit: $limit
        ) {
          id
          user_id
          actor_user_id
          action
          item_type
          item_id
          item_title
          access_source
          previous_expires_at
          new_expires_at
          note
          created_at
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(
        query: query,
        variables: {
          "user_id": userId.toString(),
          "limit": limit,
        },
      );

      final rows = List<Map<String, dynamic>>.from(
        data["user_access_audit_log"] ?? [],
      );
      if (rows.isEmpty) return rows;

      final actorIds = rows
          .map((row) => row["actor_user_id"])
          .where((value) => value != null)
          .map((value) => value.toString())
          .toSet()
          .toList(growable: false);

      if (actorIds.isEmpty) return rows;

      const usersQuery = r'''
        query GetAuditActors($ids: [bigint!]!) {
          users(where: {id: {_in: $ids}}) {
            id
            name
            email
          }
        }
      ''';

      final usersData = await _hasura.graphQLRequest(
        query: usersQuery,
        variables: {"ids": actorIds},
      );
      final users = List<Map<String, dynamic>>.from(usersData["users"] ?? []);
      final byId = <String, Map<String, dynamic>>{
        for (final user in users) user["id"].toString(): user,
      };

      return rows
          .map(
            (row) => {
              ...row,
              "actor": byId[row["actor_user_id"]?.toString()],
            },
          )
          .toList(growable: false);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("user_access_audit_log")) {
        return const [];
      }
      rethrow;
    }
  }

  String? _normalizedText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
