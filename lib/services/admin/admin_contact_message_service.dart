import '../hasura_manager.dart';

class AdminContactMessageService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    final messages = await _fetchMessages();
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

  Future<void> deleteMessage(int id) async {
    const mutation = r'''
      mutation DeleteContactMessage($id: bigint!) {
        delete_contact_messages_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
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
          }
        }
      ''';

      final data = await _hasura.graphQLRequest(query: fallbackQuery);
      return List<Map<String, dynamic>>.from(data["contact_messages"] ?? []);
    }
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

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }
}
