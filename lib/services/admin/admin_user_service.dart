import '../hasura_manager.dart';
import '../../utils/hash_helper.dart';

class AdminUserService {
  AdminUserService({HasuraManager? hasura})
    : _hasura = hasura ?? HasuraManager.instance;

  final HasuraManager _hasura;

  Future<List<Map<String, dynamic>>> getAllRoles() async {
    const query = r'''
      query GetRoles {
        roles(order_by: {id: asc}) {
          id
          name
          description
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["roles"]);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    const String query = r'''
      query GetAllUsers {
        users(order_by: {id: asc}) {
          id
          name
          email
          phone
          role_id
          role { id name }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query);

    final List users = data["users"];

    return users.map<Map<String, dynamic>>((u) {
      return {
        "id": u["id"],
        "name": u["name"],
        "email": u["email"],
        "phone": u["phone"],
        "role_id": u["role_id"],
        "role": u["role"]?["name"] ?? "User",
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> getUserDetail(int userId) async {
    const query = r'''
      query GetAdminUserDetail($id: bigint!) {
        users_by_pk(id: $id) {
          id
          name
          email
          phone
          role_id
          role {
            id
            name
          }
          avatar_url
          payUniqe
          is_active
          email_verified_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"id": userId.toString()},
    );
    final user = data["users_by_pk"] as Map<String, dynamic>?;
    if (user == null) return null;

    return {
      "id": user["id"],
      "name": user["name"],
      "email": user["email"],
      "phone": user["phone"],
      "role_id": user["role_id"],
      "role": user["role"]?["name"] ?? "User",
      "avatar_url": user["avatar_url"],
      "payUniqe": user["payUniqe"],
      "is_active": user["is_active"],
      "email_verified_at": user["email_verified_at"],
    };
  }

  Future<bool> addUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    int roleId = 1,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone?.trim();
    final hashedPassword = HashHelper.hashPassword(password);

    const String mutation = r'''
      mutation AddUser(
        $name: String!,
        $email: String!,
        $password: String!,
        $phone: String,
        $role_id: bigint!,
        $is_active: Boolean!,
        $email_verified_at: timestamptz!
      ) {
        insert_users_one(object: {
          name: $name,
          email: $email,
          password: $password,
          phone: $phone,
          role_id: $role_id,
          is_active: $is_active,
          email_verified_at: $email_verified_at
        }) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "name": normalizedName,
        "email": normalizedEmail,
        "password": hashedPassword,
        "phone": normalizedPhone == null || normalizedPhone.isEmpty
            ? null
            : normalizedPhone,
        "role_id": roleId,
        "is_active": true,
        "email_verified_at": DateTime.now().toUtc().toIso8601String(),
      },
    );

    return true;
  }

  /// Kullanıcı güncelle
  Future<bool> updateUser({
    required int id,
    required String name,
    required String email,
    String? phone,
    required int roleId,
  }) async {
    const String mutation = r'''
      mutation UpdateUser(
        $id: bigint!,
        $name: String!,
        $email: String!,
        $phone: String,
        $role_id: bigint!
      ) {
        update_users_by_pk(
          pk_columns: {id: $id},
          _set: {
            name: $name,
            email: $email,
            phone: $phone,
            role_id: $role_id
          }
        ) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "name": name,
        "email": email,
        "phone": phone,
        "role_id": roleId,
      },
    );

    return true;
  }

  /// Kullanıcı sil
  Future<bool> deleteUser(int id) async {
    const String mutation = r'''
      mutation DeleteUser($id: bigint!) {
        delete_users_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});

    return true;
  }

  Future<List<Map<String, dynamic>>> getActiveAccess(int userId) async {
    const query = r'''
      query GetUserAccess($user_id: Int!) {
        user_content_access(
          where: {
            user_id: {_eq: $user_id},
            is_active: {_eq: true}
          },
          order_by: {started_at: desc}
        ) {
          id
          item_type
          item_id
          started_at
          expires_at
          purchase_price
          is_active
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"user_id": userId},
    );

    final access = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    return _enrichAccessRecords(access);
  }

  Future<List<Map<String, dynamic>>> getAllAccess(int userId) async {
    const query = r'''
      query GetUserAccessAll($user_id: Int!) {
        user_content_access(
          where: {user_id: {_eq: $user_id}},
          order_by: {started_at: desc}
        ) {
          id
          item_type
          item_id
          started_at
          expires_at
          is_active
          purchase_price
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"user_id": userId},
    );

    final access = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    final manualAccess = await _getManualNewspaperAccess(userId);
    return _enrichAccessRecords([...access, ...manualAccess]);
  }

  Future<void> deactivateAccessEntry(Map<String, dynamic> entry) async {
    final source = (entry["source"] ?? "").toString();
    if (source == "manual_newspaper") {
      final manualId = _asInt(entry["source_id"]) ?? _asInt(entry["id"]);
      if (manualId == null) {
        throw Exception("Manuel erişim kaydı bulunamadı.");
      }
      await _deactivateManualNewspaperAccess(manualId);
      return;
    }

    final accessId = _asInt(entry["id"]);
    if (accessId == null) {
      throw Exception("Erişim kaydı bulunamadı.");
    }
    await _deactivateUserContentAccess(accessId);
  }

  Future<List<Map<String, dynamic>>> _getManualNewspaperAccess(
    int userId,
  ) async {
    const query = r'''
      query GetManualNewspaperAccess($user_id: bigint!) {
        manual_newspaper_users(
          where: {user_id: {_eq: $user_id}},
          order_by: [{ends_at: desc_nulls_last}, {id: desc}]
        ) {
          id
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
        variables: {"user_id": userId.toString()},
      );
      final rows = List<Map<String, dynamic>>.from(
        data["manual_newspaper_users"] ?? [],
      );
      return rows
          .map(
            (row) => {
              "id": "manual_${row["id"]}",
              "source_id": row["id"],
              "item_type": "newspaper_subscription",
              "item_id": null,
              "started_at": row["starts_at"],
              "expires_at": row["ends_at"],
              "is_active": row["is_active"] == true,
              "purchase_price": null,
              "source": "manual_newspaper",
              "note": row["note"],
            },
          )
          .toList(growable: false);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("manual_newspaper_users")) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> _deactivateUserContentAccess(int id) async {
    const mutation = r'''
      mutation DeactivateUserContentAccess($id: bigint!) {
        update_user_content_access_by_pk(
          pk_columns: {id: $id},
          _set: {is_active: false}
        ) {
          id
          is_active
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id.toString()},
    );
  }

  Future<void> _deactivateManualNewspaperAccess(int id) async {
    const mutation = r'''
      mutation DeactivateManualNewspaperAccess($id: bigint!) {
        update_manual_newspaper_users_by_pk(
          pk_columns: {id: $id},
          _set: {is_active: false}
        ) {
          id
          is_active
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id.toString()},
    );
  }

  Future<List<Map<String, dynamic>>> _enrichAccessRecords(
    List<Map<String, dynamic>> access,
  ) async {
    if (access.isEmpty) return access;

    final bookIds = _collectItemIds(access, "book");
    final magazineIds = _collectItemIds(access, "magazine");
    final magazineIssueIds = _collectItemIds(access, "magazine_issue");
    final newspaperTypeIds = _collectItemIds(access, "newspaper_subscription");
    final ekIds = _collectItemIds(access, "ek");

    final booksById = await _fetchBooksById(bookIds);
    final magazinesById = await _fetchMagazinesById(magazineIds);
    final issuesById = await _fetchMagazineIssuesById(magazineIssueIds);
    final newspaperTypesById = await _fetchNewspaperTypesById(newspaperTypeIds);
    final eklerById = await _fetchEklerById(ekIds);

    final enriched = access
        .map((item) {
          final type = (item["item_type"] ?? "").toString();
          final itemId = _asInt(item["item_id"]);
          final normalized = Map<String, dynamic>.from(item);

          switch (type) {
            case "book":
              final book = itemId == null ? null : booksById[itemId];
              normalized["item_title"] = book?["title"] ?? "Kitap";
              normalized["item_subtitle"] = book?["author_rel"]?["name"];
              break;
            case "magazine":
              final magazine = itemId == null ? null : magazinesById[itemId];
              normalized["item_title"] = magazine?["name"] ?? "E-dergi";
              normalized["item_subtitle"] = magazine?["category"];
              break;
            case "magazine_issue":
              final issue = itemId == null ? null : issuesById[itemId];
              final magazineName = issue?["magazine"]?["name"]?.toString();
              final rawIssueTitle = issue?["title"]?.toString().trim() ?? "";
              final issueNumber = issue?["issue_number"]?.toString();
              final issueTitle = rawIssueTitle.isNotEmpty
                  ? rawIssueTitle
                  : (issueNumber != null && issueNumber.isNotEmpty
                        ? "Sayı $issueNumber"
                        : "Dergi Sayısı");
              normalized["item_title"] = [
                if (magazineName != null && magazineName.isNotEmpty)
                  magazineName,
                if (issueTitle.isNotEmpty) issueTitle,
              ].join(" • ");
              normalized["item_subtitle"] = issue?["publish_date"]?.toString();
              break;
            case "newspaper_subscription":
              final subscriptionType = itemId == null
                  ? null
                  : newspaperTypesById[itemId];
              normalized["item_title"] =
                  subscriptionType?["title"] ??
                  (normalized["source"] == "manual_newspaper"
                      ? "Manuel E-Gazete Aboneliği"
                      : "E-Gazete Aboneliği");
              normalized["item_subtitle"] = normalized["note"]?.toString();
              break;
            case "ek":
              final ek = itemId == null ? null : eklerById[itemId];
              normalized["item_title"] = ek?["ad"] ?? "Ek";
              normalized["item_subtitle"] = ek?["aciklama"];
              break;
            default:
              normalized["item_title"] = _typeLabel(type);
              normalized["item_subtitle"] = null;
          }

          normalized["item_type_label"] = _typeLabel(type);
          return normalized;
        })
        .toList(growable: false);

    enriched.sort((a, b) {
      final aStart =
          DateTime.tryParse(a["started_at"]?.toString() ?? "") ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bStart =
          DateTime.tryParse(b["started_at"]?.toString() ?? "") ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = bStart.compareTo(aStart);
      if (cmp != 0) return cmp;
      final aExp =
          DateTime.tryParse(a["expires_at"]?.toString() ?? "") ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bExp =
          DateTime.tryParse(b["expires_at"]?.toString() ?? "") ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bExp.compareTo(aExp);
    });

    return enriched;
  }

  List<int> _collectItemIds(List<Map<String, dynamic>> access, String type) {
    return access
        .where((item) => (item["item_type"] ?? "").toString() == type)
        .map((item) => _asInt(item["item_id"]))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }

  Future<Map<int, Map<String, dynamic>>> _fetchBooksById(List<int> ids) async {
    if (ids.isEmpty) return const {};
    const query = r'''
      query GetBooksByIds($ids: [Int!]!) {
        books(where: {id: {_in: $ids}}) {
          id
          title
          author_rel: authorByAuthorId {
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
    final rows = List<Map<String, dynamic>>.from(data["books"] ?? []);
    return {
      for (final row in rows)
        if (_asInt(row["id"]) != null) _asInt(row["id"])!: row,
    };
  }

  Future<Map<int, Map<String, dynamic>>> _fetchMagazinesById(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const {};
    const query = r'''
      query GetMagazinesByIds($ids: [Int!]!) {
        magazine(where: {id: {_in: $ids}}) {
          id
          name
          category
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"ids": ids},
    );
    final rows = List<Map<String, dynamic>>.from(data["magazine"] ?? []);
    return {
      for (final row in rows)
        if (_asInt(row["id"]) != null) _asInt(row["id"])!: row,
    };
  }

  Future<Map<int, Map<String, dynamic>>> _fetchMagazineIssuesById(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const {};
    const query = r'''
      query GetMagazineIssuesByIds($ids: [Int!]!) {
        magazine_issue(where: {id: {_in: $ids}}) {
          id
          issue_number
          publish_date
          magazine {
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
    final rows = List<Map<String, dynamic>>.from(data["magazine_issue"] ?? []);
    return {
      for (final row in rows)
        if (_asInt(row["id"]) != null) _asInt(row["id"])!: row,
    };
  }

  Future<Map<int, Map<String, dynamic>>> _fetchNewspaperTypesById(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const {};
    const query = r'''
      query GetNewspaperTypesByIds($ids: [bigint!]!) {
        newspaper_subscription_type(where: {id: {_in: $ids}}) {
          id
          title
          duration_months
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"ids": ids.map((id) => id.toString()).toList()},
    );
    final rows = List<Map<String, dynamic>>.from(
      data["newspaper_subscription_type"] ?? [],
    );
    return {
      for (final row in rows)
        if (_asInt(row["id"]) != null) _asInt(row["id"])!: row,
    };
  }

  Future<Map<int, Map<String, dynamic>>> _fetchEklerById(List<int> ids) async {
    if (ids.isEmpty) return const {};
    const query = r'''
      query GetEklerByIds($ids: [bigint!]!) {
        ekler(where: {id: {_in: $ids}}) {
          id
          ad
          aciklama
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"ids": ids.map((id) => id.toString()).toList()},
    );
    final rows = List<Map<String, dynamic>>.from(data["ekler"] ?? []);
    return {
      for (final row in rows)
        if (_asInt(row["id"]) != null) _asInt(row["id"])!: row,
    };
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }

  String _typeLabel(String type) {
    switch (type) {
      case "book":
        return "Kitap";
      case "magazine":
        return "E-Dergi";
      case "magazine_issue":
        return "Dergi Sayısı";
      case "newspaper_subscription":
        return "E-Gazete";
      case "ek":
        return "Ek";
      default:
        return type;
    }
  }
}
