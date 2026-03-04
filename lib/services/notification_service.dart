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
      "https://cdn.yeniasyadigital.com/admin/notifications/send";

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
    const query = r'''
      query GetUserNotifications($user_id: bigint!) {
        notifications(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
          id
          title
          body
          created_at
          is_read
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"user_id": userId},
    );
    return List<Map<String, dynamic>>.from(data["notifications"] ?? []);
  }

  Future<Map<String, dynamic>?> getNotificationDetail(int id) async {
    const query = r'''
      query GetNotificationDetail($id: bigint!) {
        notifications_by_pk(id: $id) {
          id
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

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    int? userId,
  }) async {
    final jwt = AuthTokenStore.token?.trim();
    if (jwt == null || jwt.isEmpty) {
      throw Exception("Bildirim göndermek için geçerli bir oturum gerekli.");
    }

    final payload = <String, dynamic>{
      "title": title,
      "body": body,
      if (userId != null) "userId": userId,
      "persist": true,
      "dryRun": false,
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
}
