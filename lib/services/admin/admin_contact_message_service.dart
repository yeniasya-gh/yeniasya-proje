import '../hasura_manager.dart';

class AdminContactMessagesPageResult {
  final List<Map<String, dynamic>> items;
  final int totalCount;

  const AdminContactMessagesPageResult({
    required this.items,
    required this.totalCount,
  });
}

class AdminContactMessageService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    final messages = await _fetchMessages();
    return _attachUsers(messages);
  }

  Future<AdminContactMessagesPageResult> listMessagesPage({
    required String keyword,
    required String source,
    required String replyStatus,
    required String sort,
    required DateTime? startDate,
    required DateTime? endDate,
    required int page,
    required int pageSize,
  }) async {
    const query = r'''
      query ListContactMessagesPage(
        $keyword: String
        $source: String
        $reply_status: String
        $start_date: String
        $end_date: String
        $sort: String
        $page: Int!
        $page_size: Int!
      ) {
        contact_messages(
          keyword: $keyword
          source: $source
          reply_status: $reply_status
          start_date: $start_date
          end_date: $end_date
          sort: $sort
          page: $page
          page_size: $page_size
        ) {
          id
          subject
          message
          email
          user_id
          created_at
          reply_message
          reply_at
          reply_admin_user_id
          user {
            id
            name
            email
            phone
            role {
              id
              name
            }
          }
          reply_user {
            id
            name
            email
            phone
            role {
              id
              name
            }
          }
        }
        contact_messages_aggregate {
          aggregate {
            count
          }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {
        "keyword": keyword,
        "source": source,
        "reply_status": replyStatus,
        "start_date": _formatDateOnly(startDate),
        "end_date": _formatDateOnly(endDate),
        "sort": sort,
        "page": page,
        "page_size": pageSize,
      },
    );

    return AdminContactMessagesPageResult(
      items: List<Map<String, dynamic>>.from(data["contact_messages"] ?? []),
      totalCount: _asInt(
            data["contact_messages_aggregate"]?["aggregate"]?["count"],
          ) ??
          0,
    );
  }

  Future<void> deleteMessage(int id) async {
    const mutation = r'''
      mutation DeleteContactMessage($id: bigint!) {
        delete_contact_messages_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }

  Future<void> replyMessage({
    required int id,
    required String replyMessage,
  }) async {
    const mutation = r'''
      mutation UpdateContactMessageReply($id: bigint!, $reply_message: String!) {
        update_contact_messages_by_pk(
          pk_columns: {id: $id},
          _set: {reply_message: $reply_message}
        ) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id, "reply_message": replyMessage},
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    const queryWithCreatedAt = r'''
      query AdminContactMessages {
        contact_messages(order_by: [{created_at: desc}, {id: desc}]) {
          id
          subject
          message
          email
          user_id
          created_at
          reply_message
          reply_at
          reply_admin_user_id
          user {
            id
            name
            email
            phone
            role {
              id
              name
            }
          }
          reply_user {
            id
            name
            email
            phone
            role {
              id
              name
            }
          }
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(query: queryWithCreatedAt);
      return List<Map<String, dynamic>>.from(data["contact_messages"] ?? []);
    } catch (error) {
      if (!_looksLikeMissingField(error, "created_at")) rethrow;

      const fallbackQuery = r'''
        query AdminContactMessagesFallback {
          contact_messages(order_by: [{id: desc}]) {
            id
            subject
            message
            email
            user_id
            reply_message
            reply_at
            reply_admin_user_id
            user {
              id
              name
              email
              phone
              role {
                id
                name
              }
            }
            reply_user {
              id
              name
              email
              phone
              role {
                id
                name
              }
            }
          }
        }
      ''';

      final data = await _hasura.graphQLRequest(query: fallbackQuery);
      return List<Map<String, dynamic>>.from(data["contact_messages"] ?? []);
    }
  }

  Future<List<Map<String, dynamic>>> _attachUsers(
    List<Map<String, dynamic>> messages,
  ) async {
    final userIds =
        messages
            .map((item) => _asInt(item["user_id"]))
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();

    final usersById = userIds.isEmpty
        ? <int, Map<String, dynamic>>{}
        : await _fetchUsersByIds(userIds);

    return messages.map((item) {
      final normalized = Map<String, dynamic>.from(item);
      final userId = _asInt(normalized["user_id"]);
      if (userId != null && usersById[userId] != null) {
        normalized["user"] = usersById[userId];
      }
      return normalized;
    }).toList();
  }

  Future<Map<int, Map<String, dynamic>>> _fetchUsersByIds(List<int> ids) async {
    const query = r'''
      query AdminContactMessageUsers($ids: [bigint!]!) {
        users(where: {id: {_in: $ids}}) {
          id
          name
          email
          phone
          role {
            id
            name
          }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"ids": ids},
    );
    final users = List<Map<String, dynamic>>.from(data["users"] ?? []);

    return {
      for (final user in users)
        if (_asInt(user["id"]) != null)
          _asInt(user["id"])!: {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "phone": user["phone"],
            "role": user["role"]?["name"] ?? "User",
          },
    };
  }

  bool _looksLikeMissingField(Object error, String field) {
    final text = error.toString().toLowerCase();
    final needle = field.toLowerCase();
    return text.contains(needle) &&
        (text.contains("field") ||
            text.contains("column") ||
            text.contains("query") ||
            text.contains("cannot"));
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) return "";
    final yyyy = value.year.toString().padLeft(4, "0");
    final mm = value.month.toString().padLeft(2, "0");
    final dd = value.day.toString().padLeft(2, "0");
    return "$yyyy-$mm-$dd";
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }
}
