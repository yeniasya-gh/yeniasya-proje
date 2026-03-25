import 'hasura_manager.dart';
import 'cdn_authenticated_client.dart';

bool _isMissingAccessChannelColumnError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains("purchase_platform") ||
      message.contains("grant_source");
}

class UserContentAccessService {
  final _hasura = HasuraManager.instance;
  final _cdn = CdnAuthenticatedClient();

  Future<void> grantAccess({
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return;

    final parsedUserId = int.tryParse(userId);
    if (parsedUserId == null) {
      throw Exception("Geçersiz kullanıcı ID");
    }

    final normalizedItems = items
        .map(
          (i) => {
            "user_id": parsedUserId,
            "item_type": i["item_type"],
            "item_id": _asInt(i["item_id"]),
            "is_active": true,
            "started_at": i["started_at"],
            "expires_at": i["expires_at"],
            "purchase_price": i["purchase_price"],
            if (_normalizeText(i["grant_source"] ?? i["source"]) != null)
              "grant_source": _normalizeText(i["grant_source"] ?? i["source"]),
            if (_normalizeText(
                  i["purchase_platform"] ?? i["purchasePlatform"],
                ) !=
                null)
              "purchase_platform": _normalizeText(
                i["purchase_platform"] ?? i["purchasePlatform"],
              ),
          },
        )
        .toList(growable: false);

    final insertItems = <Map<String, dynamic>>[];
    for (final item in normalizedItems) {
      final handled = await _handleSubscriptionGrant(
        userId: parsedUserId,
        item: item,
      );
      if (!handled) {
        insertItems.add(item);
      }
    }

    if (insertItems.isEmpty) return;
    await _insertAccessRows(insertItems);
  }

  Future<Map<String, dynamic>?> getLatestGrantableAccessEntry({
    required int userId,
    required String itemType,
    int? itemId,
  }) {
    return _fetchLatestGrantableSubscriptionEntry(
      userId: userId,
      itemType: itemType,
      itemId: itemId,
    );
  }

  Future<void> _insertAccessRows(List<Map<String, dynamic>> items) async {
    const mutation = r'''
      mutation InsertAccess($items: [user_content_access_insert_input!]!) {
        insert_user_content_access(objects: $items) {
          affected_rows
        }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"items": items});
  }

  Future<List<Map<String, dynamic>>> getAccess({
    required int userId,
    required String itemType,
  }) async {
    if (_cdn.canReadUserScopedData(userId)) {
      try {
        return await _getAccessFromCdn(itemType: itemType);
      } catch (error) {
        if (!_cdn.shouldFallbackToHasura(error)) {
          rethrow;
        }
      }
    }

    return _getAccessFromHasura(userId: userId, itemType: itemType);
  }

  Future<List<Map<String, dynamic>>> getAll({required int userId}) async {
    if (_cdn.canReadUserScopedData(userId)) {
      try {
        return await _getAllFromCdn();
      } catch (error) {
        if (!_cdn.shouldFallbackToHasura(error)) {
          rethrow;
        }
      }
    }

    return _getAllFromHasura(userId: userId);
  }

  Future<List<Map<String, dynamic>>> _getAccessFromHasura({
    required int userId,
    required String itemType,
  }) async {
    const queryWithChannel = r'''
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
          grant_source
          purchase_platform
        }
      }
    ''';
    const queryWithoutChannel = r'''
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

    Map<String, dynamic> data;
    try {
      data = await _hasura.graphQLRequest(
        query: queryWithChannel,
        variables: {"user_id": userId, "item_type": itemType},
      );
    } catch (error) {
      if (!_isMissingAccessChannelColumnError(error)) {
        rethrow;
      }
      data = await _hasura.graphQLRequest(
        query: queryWithoutChannel,
        variables: {"user_id": userId, "item_type": itemType},
      );
    }

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

  Future<List<Map<String, dynamic>>> _getAllFromHasura({
    required int userId,
  }) async {
    const queryWithChannel = r'''
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
          grant_source
          purchase_platform
        }
      }
    ''';
    const queryWithoutChannel = r'''
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

    final entries = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    final manualEntries = await _getManualNewspaperAccess(userId: userId);
    entries.addAll(manualEntries);
    _sortByStartDesc(entries);
    return entries;
  }

  Future<List<Map<String, dynamic>>> _getAccessFromCdn({
    required String itemType,
  }) async {
    final data = await _cdn.getJson(
      "/auth/me/access",
      queryParameters: {"itemType": itemType},
    );
    return _readCdnEntries(data);
  }

  Future<List<Map<String, dynamic>>> _getAllFromCdn() async {
    final data = await _cdn.getJson("/auth/me/access");
    return _readCdnEntries(data);
  }

  List<Map<String, dynamic>> _readCdnEntries(Map<String, dynamic> data) {
    final entries = List<Map<String, dynamic>>.from(data["data"] ?? const []);
    _sortByStartDesc(entries);
    return entries;
  }

  Future<List<Map<String, dynamic>>> _getManualNewspaperAccess({
    required int userId,
  }) async {
    const query = r'''
      query GetManualNewspaperAccess($user_id: bigint!) {
        manual_newspaper_users(
          where: {
            user_id: {_eq: $user_id},
            is_active: {_eq: true}
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
        variables: {"user_id": userId.toString()},
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
              "is_active": row["is_active"] == true,
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

  Future<bool> _handleSubscriptionGrant({
    required int userId,
    required Map<String, dynamic> item,
  }) async {
    final itemType = (item["item_type"] ?? "").toString();
    if (!_isExtendableSubscription(itemType)) return false;

    final requestedStartedAt =
        _parseDateTime(item["started_at"]) ?? DateTime.now();
    final requestedExpiresAt = _parseDateTime(item["expires_at"]);
    if (requestedExpiresAt == null) return false;

    final extensionDuration = requestedExpiresAt.difference(requestedStartedAt);
    if (extensionDuration <= Duration.zero) return false;

    final itemId = _asInt(item["item_id"]);
    final existing = await _fetchLatestGrantableSubscriptionEntry(
      userId: userId,
      itemType: itemType,
      itemId: itemId,
    );

    if (existing == null) return false;

    final existingExpiry = _parseDateTime(existing["expires_at"]);
    if (existingExpiry == null) {
      return true;
    }

    final now = DateTime.now();
    if (!existingExpiry.isAfter(now)) {
      await _deactivateExpiredExistingEntry(
        userId: userId,
        itemType: itemType,
        itemId: itemId,
        existing: existing,
      );
      return false;
    }

    final newExpiry = existingExpiry.add(extensionDuration);
    await _updateExistingEntryExpiry(
      existing: existing,
      expiresAt: newExpiry,
      item: item,
    );
    return true;
  }

  Future<Map<String, dynamic>?> _fetchLatestGrantableSubscriptionEntry({
    required int userId,
    required String itemType,
    int? itemId,
  }) async {
    final accessEntry = await _fetchLatestActiveAccessEntry(
      userId: userId,
      itemType: itemType,
      itemId: itemId,
    );
    if (itemType != "newspaper_subscription") {
      return accessEntry;
    }

    final manualEntry = await _fetchLatestActiveManualNewspaperEntry(
      userId: userId,
    );
    return _pickLaterExpiryEntry(accessEntry, manualEntry);
  }

  Future<Map<String, dynamic>?> _fetchLatestActiveAccessEntry({
    required int userId,
    required String itemType,
    int? itemId,
  }) async {
    final query = itemId == null
        ? r'''
      query GetLatestAccess($user_id: Int!, $item_type: access_item_type!) {
        user_content_access(
          where: {
            user_id: {_eq: $user_id},
            item_type: {_eq: $item_type},
            item_id: {_is_null: true},
            is_active: {_eq: true}
          },
          order_by: [{expires_at: desc_nulls_last}, {started_at: desc_nulls_last}, {id: desc}],
          limit: 1
        ) {
          id
          item_id
          item_type
          started_at
          expires_at
          is_active
        }
      }
    '''
        : r'''
      query GetLatestAccess(
        $user_id: Int!,
        $item_type: access_item_type!,
        $item_id: Int!
      ) {
        user_content_access(
          where: {
            user_id: {_eq: $user_id},
            item_type: {_eq: $item_type},
            item_id: {_eq: $item_id},
            is_active: {_eq: true}
          },
          order_by: [{expires_at: desc_nulls_last}, {started_at: desc_nulls_last}, {id: desc}],
          limit: 1
        ) {
          id
          item_id
          item_type
          started_at
          expires_at
          is_active
        }
      }
    ''';

    final variables = <String, dynamic>{
      "user_id": userId,
      "item_type": itemType,
      if (itemId != null) "item_id": itemId,
    };
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: variables,
    );
    final rows = List<Map<String, dynamic>>.from(
      data["user_content_access"] ?? [],
    );
    if (rows.isEmpty) return null;
    return {...rows.first, "source": "user_content_access"};
  }

  Future<Map<String, dynamic>?> _fetchLatestActiveManualNewspaperEntry({
    required int userId,
  }) async {
    const query = r'''
      query GetLatestManualNewspaperAccess($user_id: bigint!) {
        manual_newspaper_users(
          where: {
            user_id: {_eq: $user_id},
            is_active: {_eq: true}
          },
          order_by: [{ends_at: desc_nulls_last}, {starts_at: desc_nulls_last}, {id: desc}],
          limit: 1
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
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        "id": row["id"],
        "item_type": "newspaper_subscription",
        "item_id": null,
        "started_at": row["starts_at"],
        "expires_at": row["ends_at"],
        "is_active": row["is_active"] == true,
        "note": row["note"],
        "source": "manual_newspaper",
      };
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains("manual_newspaper_users")) {
        return null;
      }
      rethrow;
    }
  }

  Map<String, dynamic>? _pickLaterExpiryEntry(
    Map<String, dynamic>? first,
    Map<String, dynamic>? second,
  ) {
    if (first == null) return second;
    if (second == null) return first;

    final firstExpiry = _parseDateTime(first["expires_at"]);
    final secondExpiry = _parseDateTime(second["expires_at"]);

    if (firstExpiry == null) return second;
    if (secondExpiry == null) return first;
    if (secondExpiry.isAfter(firstExpiry)) return second;
    return first;
  }

  Future<void> _deactivateExpiredActiveAccessRows({
    required int userId,
    required String itemType,
    int? itemId,
  }) async {
    final mutation = itemId == null
        ? r'''
      mutation DeactivateExpiredAccess(
        $user_id: Int!,
        $item_type: access_item_type!,
        $now: timestamptz!
      ) {
        update_user_content_access(
          where: {
            user_id: {_eq: $user_id},
            item_type: {_eq: $item_type},
            item_id: {_is_null: true},
            is_active: {_eq: true},
            expires_at: {_lte: $now}
          },
          _set: {is_active: false}
        ) {
          affected_rows
        }
      }
    '''
        : r'''
      mutation DeactivateExpiredAccess(
        $user_id: Int!,
        $item_type: access_item_type!,
        $item_id: Int!,
        $now: timestamptz!
      ) {
        update_user_content_access(
          where: {
            user_id: {_eq: $user_id},
            item_type: {_eq: $item_type},
            item_id: {_eq: $item_id},
            is_active: {_eq: true},
            expires_at: {_lte: $now}
          },
          _set: {is_active: false}
        ) {
          affected_rows
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "user_id": userId,
        "item_type": itemType,
        "now": DateTime.now().toIso8601String(),
        if (itemId != null) "item_id": itemId,
      },
    );
  }

  Future<void> _deactivateExpiredExistingEntry({
    required int userId,
    required String itemType,
    required int? itemId,
    required Map<String, dynamic> existing,
  }) async {
    final source = (existing["source"] ?? "user_content_access").toString();
    if (source == "manual_newspaper") {
      final manualId = _asInt(existing["id"]);
      if (manualId == null) return;
      await _deactivateManualNewspaperAccess(manualId);
      return;
    }

    await _deactivateExpiredActiveAccessRows(
      userId: userId,
      itemType: itemType,
      itemId: itemId,
    );
  }

  Future<void> _updateAccessExpiry({
    required int? accessId,
    required DateTime expiresAt,
    String? grantSource,
    String? purchasePlatform,
  }) async {
    if (accessId == null) return;

    const mutationWithBoth = r'''
      mutation UpdateAccessExpiry(
        $id: Int!,
        $expires_at: timestamptz!,
        $grant_source: String,
        $purchase_platform: String
      ) {
        update_user_content_access_by_pk(
          pk_columns: {id: $id},
          _set: {
            expires_at: $expires_at,
            grant_source: $grant_source,
            purchase_platform: $purchase_platform
          }
        ) {
          id
          expires_at
        }
      }
    ''';
    const mutationWithGrantSource = r'''
      mutation UpdateAccessExpiry(
        $id: Int!,
        $expires_at: timestamptz!,
        $grant_source: String
      ) {
        update_user_content_access_by_pk(
          pk_columns: {id: $id},
          _set: {
            expires_at: $expires_at,
            grant_source: $grant_source
          }
        ) {
          id
          expires_at
        }
      }
    ''';
    const mutationWithPurchasePlatform = r'''
      mutation UpdateAccessExpiry(
        $id: Int!,
        $expires_at: timestamptz!,
        $purchase_platform: String
      ) {
        update_user_content_access_by_pk(
          pk_columns: {id: $id},
          _set: {
            expires_at: $expires_at,
            purchase_platform: $purchase_platform
          }
        ) {
          id
          expires_at
        }
      }
    ''';
    const mutationWithoutMetadata = r'''
      mutation UpdateAccessExpiry($id: Int!, $expires_at: timestamptz!) {
        update_user_content_access_by_pk(
          pk_columns: {id: $id},
          _set: {expires_at: $expires_at}
        ) {
          id
          expires_at
        }
      }
    ''';

    final variables = {
      "id": accessId,
      "expires_at": expiresAt.toIso8601String(),
      "grant_source": grantSource,
      "purchase_platform": purchasePlatform,
    };

    if (grantSource != null && purchasePlatform != null) {
      await _hasura.graphQLRequest(
        query: mutationWithBoth,
        variables: variables,
      );
      return;
    }
    if (grantSource != null) {
      await _hasura.graphQLRequest(
        query: mutationWithGrantSource,
        variables: {
          "id": accessId,
          "expires_at": expiresAt.toIso8601String(),
          "grant_source": grantSource,
        },
      );
      return;
    }
    if (purchasePlatform != null) {
      await _hasura.graphQLRequest(
        query: mutationWithPurchasePlatform,
        variables: {
          "id": accessId,
          "expires_at": expiresAt.toIso8601String(),
          "purchase_platform": purchasePlatform,
        },
      );
      return;
    }

    await _hasura.graphQLRequest(
      query: mutationWithoutMetadata,
      variables: {"id": accessId, "expires_at": expiresAt.toIso8601String()},
    );
  }

  Future<void> _updateManualNewspaperExpiry({
    required int? accessId,
    required DateTime expiresAt,
  }) async {
    if (accessId == null) return;

    const mutation = r'''
      mutation UpdateManualNewspaperExpiry(
        $id: bigint!,
        $ends_at: timestamptz!,
        $updated_at: timestamptz!
      ) {
        update_manual_newspaper_users_by_pk(
          pk_columns: {id: $id},
          _set: {
            ends_at: $ends_at,
            updated_at: $updated_at
          }
        ) {
          id
          ends_at
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": accessId.toString(),
        "ends_at": expiresAt.toIso8601String(),
        "updated_at": DateTime.now().toUtc().toIso8601String(),
      },
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

  Future<void> _updateExistingEntryExpiry({
    required Map<String, dynamic> existing,
    required DateTime expiresAt,
    Map<String, dynamic>? item,
  }) async {
    final source = (existing["source"] ?? "user_content_access").toString();
    if (source == "manual_newspaper") {
      await _updateManualNewspaperExpiry(
        accessId: _asInt(existing["id"]),
        expiresAt: expiresAt,
      );
      return;
    }

    await _updateAccessExpiry(
      accessId: _asInt(existing["id"]),
      expiresAt: expiresAt,
      grantSource: _normalizeText(item?["grant_source"] ?? item?["source"]),
      purchasePlatform: _normalizeText(
        item?["purchase_platform"] ?? item?["purchasePlatform"],
      ),
    );
  }

  bool _isExtendableSubscription(String itemType) {
    return itemType == "magazine" || itemType == "newspaper_subscription";
  }

  DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String? _normalizeText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
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
