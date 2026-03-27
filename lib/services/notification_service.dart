import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_token_store.dart';
import 'hasura_manager.dart';

class NotificationService {
  final _hasura = HasuraManager.instance;
  final http.Client _http = http.Client();
  static const String _pushApiUrl =
      "https://cdn.yeniasyadijital.com/admin/notifications/send";

  Future<void> registerDeviceToken({
    required int userId,
    bool forceRefresh = false,
  }) async {
    // Web'de FCM izin akışı ve token alma kullanıcı etkileşimi gerektirdiği ve çoğunlukla kapalı olduğu için sessizce atla.
    if (kIsWeb) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      // Android/iOS'ta izin iste (Android 13+ için gerekli).
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      // Önce mevcut token'ı almaya çalış
      String? token = await messaging.getToken();

      // Token null ise izin iste ve tekrar dene (Android/iOS).
      if (token == null || forceRefresh) {
        try {
          await messaging.deleteToken();
        } catch (_) {}
        token = await messaging.getToken();
      }

      if (token == null) return;

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
          "firebase_token_updated_at": DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Bildirim izni kapalı veya tarayıcı tarafından engelliyse sessizce yut.
      return;
    }
  }

  Future<List<Map<String, dynamic>>> getTokens() async {
    const query = r'''
      query GetTokens {
        users(
          where: {firebase_token: {_is_null: false, _neq: ""}}
          order_by: {firebase_token_updated_at: desc}
        ) {
          id
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
            "id": u["id"],
            "user_id": u["id"],
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
    return List<Map<String, dynamic>>.from(data["notifications"] ?? []);
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
    return data["notifications_by_pk"] as Map<String, dynamic>?;
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
    return List<Map<String, dynamic>>.from(data["notifications"] ?? const []);
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
}
