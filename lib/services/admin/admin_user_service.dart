import '../cdn_authenticated_client.dart';
import '../hasura_manager.dart';
import '../../utils/hash_helper.dart';
import '../../utils/purchase_channel_labels.dart';

bool _isMissingAccessChannelColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("purchase_platform") ||
      message.contains("grant_source");
}

bool _isMissingDeactivatedAtColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("deactivated_at");
}

bool _isAccessRemovalFallbackError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("update_user_content_access") ||
      message.contains("update_manual_newspaper_users") ||
      message.contains("permission denied") ||
      message.contains("not found") ||
      message.contains("constraint") ||
      message.contains("mutation") ||
      message.contains("graphql");
}

class AdminUserService {
  AdminUserService({HasuraManager? hasura, CdnAuthenticatedClient? cdnClient})
    : _hasura = hasura ?? HasuraManager.instance,
      _cdn = cdnClient ?? CdnAuthenticatedClient();

  final HasuraManager _hasura;
  final CdnAuthenticatedClient _cdn;

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
        users(
          where: {is_active: {_eq: true}},
          order_by: {id: asc}
        ) {
          id
          name
          email
          phone
          role_id
          is_active
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
        "is_active": u["is_active"] == true,
        "role": u["role"]?["name"] ?? "User",
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> getUserDetail(int userId) async {
    const queryWithDeactivatedAt = r'''
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
          deactivated_at
        }
      }
    ''';
    const queryWithoutDeactivatedAt = r'''
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

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(
        query: queryWithDeactivatedAt,
        variables: {"id": userId.toString()},
      );
    } catch (error) {
      if (!_isMissingDeactivatedAtColumnError(error)) {
        rethrow;
      }
      data = await _hasura.graphQLRequest(
        query: queryWithoutDeactivatedAt,
        variables: {"id": userId.toString()},
      );
    }
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
      "deactivated_at": user["deactivated_at"],
    };
  }

  Future<List<Map<String, dynamic>>> getPassiveUsers() async {
    const queryWithDeactivatedAt = r'''
      query GetPassiveUsers {
        users(
          where: {is_active: {_eq: false}},
          order_by: [{deactivated_at: desc_nulls_last}, {id: desc}]
        ) {
          id
          name
          email
          phone
          role_id
          is_active
          deactivated_at
          email_verified_at
          role { id name }
        }
      }
    ''';
    const queryWithoutDeactivatedAt = r'''
      query GetPassiveUsers {
        users(
          where: {is_active: {_eq: false}},
          order_by: {id: desc}
        ) {
          id
          name
          email
          phone
          role_id
          is_active
          email_verified_at
          role { id name }
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(query: queryWithDeactivatedAt);
      return _mapPassiveUsers(data);
    } catch (error) {
      if (!_isMissingDeactivatedAtColumnError(error)) {
        try {
          final fallbackData = await _hasura.graphQLRequest(
            query: queryWithoutDeactivatedAt,
          );
          return _mapPassiveUsers(fallbackData);
        } catch (_) {
          return _getPassiveUsersFromAllUsers();
        }
      }
      try {
        final data = await _hasura.graphQLRequest(
          query: queryWithoutDeactivatedAt,
        );
        return _mapPassiveUsers(data);
      } catch (_) {
        return _getPassiveUsersFromAllUsers();
      }
    }
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

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final phoneValue =
        normalizedPhone == null || normalizedPhone.isEmpty ? null : normalizedPhone;

    Future<void> createUser() async {
      await _hasura.graphQLRequest(
        query: mutation,
        variables: {
          "name": normalizedName,
          "email": normalizedEmail,
          "password": hashedPassword,
          "phone": phoneValue,
          "role_id": roleId,
          "is_active": true,
          "email_verified_at": nowIso,
        },
      );
    }

    try {
      await createUser();
      return true;
    } catch (error) {
      if (!_isDuplicateConstraintError(error)) {
        rethrow;
      }

      final purgeResult = await _purgeInactiveUsersByIdentity(
        email: normalizedEmail,
        phone: phoneValue,
      );
      if ((purgeResult["deletedUserIds"] as List<dynamic>? ?? const []).isEmpty) {
        rethrow;
      }

      await createUser();
      return true;
    }
  }

  Future<Map<String, dynamic>> _purgeInactiveUsersByIdentity({
    required String email,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      "email": email.trim().toLowerCase(),
      if (phone != null && phone.trim().isNotEmpty) "phone": phone.trim(),
    };

    final response = await _cdn.postJson("/admin/users/purge", body: body);
    return response;
  }

  Future<void> hardDeleteUser(int id) async {
    await _cdn.postJson("/admin/users/purge", body: {"userId": id});
  }

  bool _isDuplicateConstraintError(Object error) {
    final message = error.toString().toLowerCase();
    if (!message.contains("duplicate key value violates unique constraint")) {
      return false;
    }
    return message.contains("users_email_key") ||
        message.contains("users_phone_key") ||
        message.contains("users_email_active_unique_idx") ||
        message.contains("users_phone_active_unique_idx") ||
        message.contains("users_email_lower_unique_idx");
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
    const softDeleteMutationWithDeactivatedAt = r'''
      mutation DeactivateUser(
        $id: bigint!,
        $deactivated_at: timestamptz!
      ) {
        update_users_by_pk(
          pk_columns: {id: $id},
          _set: {
            is_active: false,
            deactivated_at: $deactivated_at
          }
        ) {
          id
          is_active
          deactivated_at
        }
      }
    ''';

    const softDeleteMutationWithoutDeactivatedAt = r'''
      mutation DeactivateUser($id: bigint!) {
        update_users_by_pk(
          pk_columns: {id: $id},
          _set: {
            is_active: false
          }
        ) {
          id
          is_active
        }
      }
    ''';

    Map<String, dynamic> softDeleteData;
    try {
      softDeleteData = await _hasura.graphQLRequest(
        query: softDeleteMutationWithDeactivatedAt,
        variables: {
          "id": id,
          "deactivated_at": DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (error) {
      if (!_isMissingDeactivatedAtColumnError(error)) {
        rethrow;
      }
      softDeleteData = await _hasura.graphQLRequest(
        query: softDeleteMutationWithoutDeactivatedAt,
        variables: {"id": id},
      );
    }

    return softDeleteData["update_users_by_pk"] != null;
  }

  Future<List<Map<String, dynamic>>> getActiveAccess(int userId) async {
    const queryWithChannel = r'''
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
          grant_source
          purchase_platform
        }
      }
    ''';
    const queryWithoutChannel = r'''
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

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(
        query: queryWithChannel,
        variables: {"user_id": userId},
      );
    } catch (error) {
      if (!_isMissingAccessChannelColumnError(error)) {
        rethrow;
      }
      data = await _hasura.graphQLRequest(
        query: queryWithoutChannel,
        variables: {"user_id": userId},
      );
    }

    final access = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    return _enrichAccessRecords(access);
  }

  Future<List<Map<String, dynamic>>> getAllAccess(int userId) async {
    const queryWithChannel = r'''
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
          grant_source
          purchase_platform
        }
      }
    ''';
    const queryWithoutChannel = r'''
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

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(
        query: queryWithChannel,
        variables: {"user_id": userId},
      );
    } catch (error) {
      if (!_isMissingAccessChannelColumnError(error)) {
        rethrow;
      }
      data = await _hasura.graphQLRequest(
        query: queryWithoutChannel,
        variables: {"user_id": userId},
      );
    }

    final access = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    final manualAccess = await _getManualNewspaperAccess(userId);
    return _enrichAccessRecords([...access, ...manualAccess]);
  }

  Future<void> deactivateAccessEntry(Map<String, dynamic> entry) async {
    final source = _resolveAccessSource(entry);
    if (source == "manual_newspaper") {
      final manualId = _asInt(entry["source_id"]) ?? _asInt(entry["id"]);
      if (manualId == null) {
        throw Exception("Manuel erişim kaydı bulunamadı.");
      }
      await _toggleManualNewspaperAccess(manualId);
      return;
    }

    final accessId = _asInt(entry["id"]) ?? _asInt(entry["source_id"]);
    if (accessId == null) {
      throw Exception("Erişim kaydı bulunamadı.");
    }
    await _toggleUserContentAccess(accessId);
  }

  String _resolveAccessSource(Map<String, dynamic> entry) {
    final source = (entry["source"] ?? entry["access_source"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    if (source.isNotEmpty) {
      return source;
    }

    if (_asInt(entry["source_id"]) != null) {
      return "manual_newspaper";
    }

    final idText = entry["id"]?.toString().trim() ?? "";
    if (idText.startsWith("manual_")) {
      return "manual_newspaper";
    }

    return "";
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
          status
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
              "status": row["status"],
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

  Future<void> _toggleUserContentAccess(int id) async {
    const mutation = r'''
      mutation DeactivateUserContentAccess($id: Int!) {
        update_user_content_access(
          where: {id: {_eq: $id}},
          _set: {is_active: false}
        ) {
          affected_rows
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(
        query: mutation,
        variables: {"id": id},
      );
      final affected =
          data["update_user_content_access"]?["affected_rows"] as int? ?? 0;
      if (affected > 0) return;
      throw Exception("Erişim pasife çekilemedi.");
    } catch (error) {
      if (!_isAccessRemovalFallbackError(error)) rethrow;
      await _deleteUserContentAccess(id);
    }
  }

  Future<void> _toggleManualNewspaperAccess(int id) async {
    const mutation = r'''
      mutation DeactivateManualNewspaperAccess($id: bigint!) {
        update_manual_newspaper_users(
          where: {id: {_eq: $id}},
          _set: {is_active: false}
        ) {
          affected_rows
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(
        query: mutation,
        variables: {"id": id.toString()},
      );
      final affected =
          data["update_manual_newspaper_users"]?["affected_rows"] as int? ?? 0;
      if (affected > 0) return;
      throw Exception("Manuel erişim pasife çekilemedi.");
    } catch (error) {
      if (!_isAccessRemovalFallbackError(error)) rethrow;
      await _deleteManualNewspaperAccess(id);
    }
  }

  Future<void> _deleteUserContentAccess(int id) async {
    const mutation = r'''
      mutation DeleteUserContentAccess($id: Int!) {
        delete_user_content_access(where: {id: {_eq: $id}}) {
          affected_rows
        }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }

  Future<void> _deleteManualNewspaperAccess(int id) async {
    const mutation = r'''
      mutation DeleteManualNewspaperAccess($id: bigint!) {
        delete_manual_newspaper_users(where: {id: {_eq: $id}}) {
          affected_rows
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id.toString()},
    );
  }

  List<Map<String, dynamic>> _mapPassiveUsers(Map<String, dynamic> data) {
    final List users = data["users"] ?? const [];
    return users
        .where((u) => u["is_active"] == false)
        .map<Map<String, dynamic>>((u) {
          return {
            "id": u["id"],
            "name": u["name"],
            "email": u["email"],
            "phone": u["phone"],
            "role_id": u["role_id"],
            "is_active": u["is_active"] == true,
            "role": u["role"]?["name"] ?? "User",
            "deactivated_at": u["deactivated_at"],
            "email_verified_at": u["email_verified_at"],
          };
        })
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _getPassiveUsersFromAllUsers() async {
    const queryWithDeactivatedAt = r'''
      query GetPassiveUsersFallback {
        users(order_by: {id: desc}) {
          id
          name
          email
          phone
          role_id
          is_active
          deactivated_at
          email_verified_at
          role { id name }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: queryWithDeactivatedAt);
    return _mapPassiveUsers(data);
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
              normalized["item_subtitle"] =
                  issue?["added_at"]?.toString() ??
                  issue?["created_at"]?.toString();
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
          normalized["access_channel_label"] =
              PurchaseChannelLabels.accessChannelLabel(normalized);
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
          added_at
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
