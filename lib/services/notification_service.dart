import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_token_store.dart';
import 'hasura_manager.dart';
import '../firebase_options.dart';

class AdminNotificationsPageResult {
  final List<Map<String, dynamic>> items;
  final int totalCount;

  const AdminNotificationsPageResult({
    required this.items,
    required this.totalCount,
  });
}

class NotificationService {
  final _hasura = HasuraManager.instance;
  final http.Client _http = http.Client();
  static const String _pushApiUrl =
      "https://cdn.yeniasyadijital.com/admin/notifications/send";
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static int? _registeredUserId;
  static bool _tokenRefreshListenerAttached = false;

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<void> _ensureTokenRefreshListener() async {
    if (_tokenRefreshListenerAttached) return;
    final messaging = FirebaseMessaging.instance;
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
      final userId = _registeredUserId;
      if (userId == null || token.trim().isEmpty) return;
      unawaited(
        _persistDeviceToken(
          userId: userId,
          token: token,
          updatedAt: DateTime.now(),
        ),
      );
    });
    _tokenRefreshListenerAttached = true;
  }

  Future<void> _persistDeviceToken({
    required int userId,
    required String token,
    required DateTime updatedAt,
  }) async {
    const mutation = r'''
      mutation UpdateUserToken(
        $user_id: bigint!,
        $token: String!,
        $firebase_token_updated_at: timestamptz!
      ) {
        update_users_by_pk(pk_columns: {id: $user_id}, _set: {firebase_token: $token, firebase_token_updated_at: $firebase_token_updated_at}) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "user_id": userId,
        "token": token,
        "firebase_token_updated_at": updatedAt.toIso8601String(),
      },
    );
  }

  Future<String?> _tryGetFirebaseToken(
    FirebaseMessaging messaging, {
    bool forceRefresh = false,
  }) async {
    String? token = await messaging.getToken();
    if ((token == null || token.trim().isEmpty) && forceRefresh) {
      try {
        await messaging.deleteToken();
      } catch (_) {}
      token = await messaging.getToken();
    }
    return token;
  }

  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    final isApplePlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (!isApplePlatform) return null;

    for (var i = 0; i < 10; i++) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.trim().isNotEmpty) {
        return apnsToken;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return messaging.getAPNSToken();
  }

  Future<void> registerDeviceToken({
    required int userId,
    bool forceRefresh = false,
  }) async {
    // Web'de FCM izin akışı ve token alma kullanıcı etkileşimi gerektirdiği ve çoğunlukla kapalı olduğu için sessizce atla.
    if (kIsWeb) return;

    try {
      await _ensureFirebaseInitialized();
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      // Android/iOS'ta izin iste (Android 13+ için gerekli).
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      final isApplePlatform =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);
      if (isApplePlatform) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        await _waitForApnsToken(messaging);
      }

      _registeredUserId = userId;
      await _ensureTokenRefreshListener();

      final token = await _tryGetFirebaseToken(
        messaging,
        forceRefresh: forceRefresh,
      );

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          "iOS/Android notification token not ready yet; waiting for refresh.",
        );
        return;
      }

      await _persistDeviceToken(
        userId: userId,
        token: token,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      // Bildirim izni kapalı veya tarayıcı tarafından engelliyse sessizce yut.
      return;
    }
  }

  void clearRegisteredUser() {
    _registeredUserId = null;
  }

  Future<List<Map<String, dynamic>>> getTokens() async {
    const query = r'''
      query GetTokens {
        users(
          where: {firebase_token: {_is_null: false, _neq: ""}}
          order_by: {firebase_token_updated_at: desc}
        ) {
          id
          name
          email
          firebase_token
          firebase_token_updated_at
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(query: query);
    final users = List<Map<String, dynamic>>.from(data["users"] ?? []);
    return users
        .map(
          (u) => <String, dynamic>{
            "id": _asInt(u["id"]) ?? u["id"],
            "user_id": _asInt(u["id"]) ?? u["id"],
            "name": u["name"],
            "email": u["email"],
            "token": u["firebase_token"],
            "platform": null,
            "updated_at": u["firebase_token_updated_at"],
          },
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    return getUserNotificationsFiltered(userId);
  }

  Future<List<Map<String, dynamic>>> getUserNotificationsFiltered(
    int userId, {
    bool? isRead,
  }) async {
    const query = r'''
      query GetUserNotifications($where: notifications_bool_exp!) {
        notifications(where: $where, order_by: {created_at: desc}) {
          id
          user_id
          title
          body
          created_at
          is_read
        }
      }
    ''';
    final where = <String, dynamic>{
      "user_id": {"_eq": userId},
    };
    if (isRead != null) {
      where["is_read"] = {"_eq": isRead};
    }
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"where": where},
    );
    return List<Map<String, dynamic>>.from(
      data["notifications"] ?? [],
    ).map(_normalizeNotificationRow).toList(growable: false);
  }

  Future<Map<String, dynamic>?> getNotificationDetail(int id) async {
    const query = r'''
      query GetNotificationDetail($id: Int!) {
        notifications_by_pk(id: $id) {
          id
          user_id
          title
          body
          created_at
          is_read
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"id": id},
    );
    final detail = data["notifications_by_pk"] as Map<String, dynamic>?;
    if (detail == null) return null;
    return _normalizeNotificationRow(detail);
  }

  Future<List<Map<String, dynamic>>> getAdminNotifications({
    String? search,
    bool? isRead,
    int limit = 200,
  }) async {
    const query = r'''
      query GetAdminNotifications($where: notifications_bool_exp!, $limit: Int!) {
        notifications(where: $where, order_by: {created_at: desc}, limit: $limit) {
          id
          user_id
          title
          body
          created_at
          is_read
          user {
            id
            name
            email
          }
        }
      }
    ''';

    final filters = <Map<String, dynamic>>[{}];
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim();
      filters.add({
        "_or": [
          {
            "title": {"_ilike": "%$q%"},
          },
          {
            "body": {"_ilike": "%$q%"},
          },
        ],
      });
    }
    if (isRead != null) {
      filters.add({
        "is_read": {"_eq": isRead},
      });
    }

    final where = filters.length == 1
        ? <String, dynamic>{}
        : {"_and": filters.where((item) => item.isNotEmpty).toList()};

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"where": where, "limit": limit},
    );
    return List<Map<String, dynamic>>.from(
      data["notifications"] ?? const [],
    ).map(_normalizeNotificationRow).toList(growable: false);
  }

  Future<AdminNotificationsPageResult> listAdminNotificationsPage({
    String keyword = "",
    bool? isRead,
    int page = 1,
    int pageSize = 20,
  }) async {
    const query = r'''
      query ListAdminNotificationsPage(
        $keyword: String
        $is_read: Boolean
        $page: Int!
        $page_size: Int!
      ) {
        notifications(
          keyword: $keyword
          is_read: $is_read
          page: $page
          page_size: $page_size
        ) {
          id
          user_id
          title
          body
          created_at
          is_read
          user {
            id
            name
            email
          }
        }
        notifications_aggregate(
          keyword: $keyword
          is_read: $is_read
        ) {
          aggregate {
            count
          }
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {
        "keyword": keyword.trim().isEmpty ? null : keyword.trim(),
        "is_read": isRead,
        "page": page < 1 ? 1 : page,
        "page_size": pageSize < 1 ? 20 : pageSize,
      },
    );

    return AdminNotificationsPageResult(
      items: List<Map<String, dynamic>>.from(data["notifications"] ?? const [])
          .map(_normalizeNotificationRow)
          .toList(growable: false),
      totalCount: _asInt(
            data["notifications_aggregate"]?["aggregate"]?["count"],
          ) ??
          0,
    );
  }

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    int? userId,
    List<int>? userIds,
    bool persist = true,
    bool dryRun = false,
  }) async {
    final jwt = AuthTokenStore.token?.trim();
    if (jwt == null || jwt.isEmpty) {
      throw Exception("Bildirim göndermek için geçerli bir oturum gerekli.");
    }

    final payload = <String, dynamic>{
      "title": title,
      "body": body,
      if (userIds != null && userIds.isNotEmpty) "userIds": userIds,
      if ((userIds == null || userIds.isEmpty) && userId != null)
        "userId": userId,
      "persist": persist,
      "dryRun": dryRun,
    };
    final response = await _http
        .post(
          Uri.parse(_pushApiUrl),
          headers: {
            "content-type": "application/json",
            "authorization": "Bearer $jwt",
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    Map<String, dynamic> decoded = const {};
    final raw = response.body.trim();
    if (raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        decoded = parsed;
      } else if (parsed is Map) {
        decoded = Map<String, dynamic>.from(parsed);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded["error"]?.toString();
      throw Exception(
        error?.isNotEmpty == true
            ? error
            : "Bildirim gönderilemedi (${response.statusCode}).",
      );
    }

    if (decoded["ok"] != true) {
      throw Exception(
        decoded["error"]?.toString() ?? "Bildirim servisi hata döndürdü.",
      );
    }

    return decoded;
  }

  Future<void> markNotificationRead({
    required int id,
    required bool isRead,
  }) async {
    const mutation = r'''
      mutation UpdateNotificationRead($id: Int!, $is_read: Boolean!) {
        update_notifications_by_pk(
          pk_columns: {id: $id},
          _set: {is_read: $is_read}
        ) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"id": id, "is_read": isRead},
    );
  }

  Future<void> deleteNotification(int id) async {
    const mutation = r'''
      mutation DeleteNotification($id: Int!) {
        delete_notifications_by_pk(id: $id) {
          id
        }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
  }

  Map<String, dynamic> _normalizeNotificationRow(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    final id = _asInt(normalized["id"]);
    if (id != null) normalized["id"] = id;
    final userId = _asInt(normalized["user_id"]);
    if (userId != null) normalized["user_id"] = userId;
    final user = normalized["user"];
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      final nestedUserId = _asInt(userMap["id"]);
      if (nestedUserId != null) userMap["id"] = nestedUserId;
      normalized["user"] = userMap;
    }
    return normalized;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }
}
