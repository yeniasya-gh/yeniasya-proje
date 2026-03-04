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
            .map(
              (i) => {
                "user_id": parsedUserId,
                "item_type": i["item_type"],
                "item_id": i["item_id"],
                "is_active": true,
                "started_at": i["started_at"],
                "expires_at": i["expires_at"],
                "purchase_price": i["purchase_price"],
              },
            )
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

    final entries = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    if (itemType == "newspaper_subscription") {
      final manualEntries = await _getManualNewspaperAccess(userId: userId);
      entries.addAll(manualEntries);
    }
    _sortByStartDesc(entries);
    return entries;
  }

  Future<List<Map<String, dynamic>>> getAll({required int userId}) async {
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

    final entries = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    final manualEntries = await _getManualNewspaperAccess(userId: userId);
    entries.addAll(manualEntries);
    _sortByStartDesc(entries);
    return entries;
  }

  Future<List<Map<String, dynamic>>> _getManualNewspaperAccess({
    required int userId,
  }) async {
    const query = r'''
      query GetManualNewspaperAccess($user_id: bigint!, $now: timestamptz!) {
        manual_newspaper_users(
          where: {
            user_id: {_eq: $user_id},
            is_active: {_eq: true},
            ends_at: {_gt: $now}
          },
          order_by: [{ends_at: desc}, {id: desc}]
        ) {
          id
          user_id
          starts_at
          ends_at
          is_active
          note
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(
        query: query,
        variables: {
          "user_id": userId.toString(),
          "now": DateTime.now().toUtc().toIso8601String(),
        },
      );
      final rows = List<Map<String, dynamic>>.from(
        data["manual_newspaper_users"] ?? [],
      );

      return rows
          .map(
            (row) => {
              "id": "manual_${row["id"]}",
              "item_id": null,
              "item_type": "newspaper_subscription",
              "started_at": row["starts_at"],
              "expires_at": row["ends_at"],
              "source": "manual_newspaper",
              "note": row["note"],
            },
          )
          .toList();
    } catch (e) {
      // Migration henüz uygulanmamışsa erişim sorgusunu sessizce atla.
      final msg = e.toString().toLowerCase();
      if (msg.contains("manual_newspaper_users")) {
        return const [];
      }
      rethrow;
    }
  }

  void _sortByStartDesc(List<Map<String, dynamic>> entries) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.tryParse(value.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    entries.sort((a, b) {
      final aStart = parseDate(a["started_at"]);
      final bStart = parseDate(b["started_at"]);
      final cmp = bStart.compareTo(aStart);
      if (cmp != 0) return cmp;
      final aExp = parseDate(a["expires_at"]);
      final bExp = parseDate(b["expires_at"]);
      return bExp.compareTo(aExp);
    });
  }
}
