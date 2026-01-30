import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'hasura_manager.dart';

class NotificationService {
  final _hasura = HasuraManager.instance;

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

  Future<bool> sendNotification({
    required String title,
    required String body,
    int? userId,
  }) async {
    // Backend tarafında FCM gönderimini tetiklemek için kayıt
    const mutation = r'''
      mutation InsertNotification($title: String!, $body: String!, $user_id: bigint) {
        insert_notifications_one(object: {
          title: $title,
          body: $body,
          user_id: $user_id
        }) { id }
      }
    ''';
    await _hasura.graphQLRequest(
      query: mutation,
      variables: {"title": title, "body": body, "user_id": userId},
    );
    return true;
  }
}
