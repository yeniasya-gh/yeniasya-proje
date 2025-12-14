import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'hasura_manager.dart';

class NotificationService {
  final _hasura = HasuraManager.instance;

  Future<void> registerDeviceToken({required int userId, bool forceRefresh = false}) async {
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
        mutation UpsertToken(
          $user_id: bigint!,
          $token: String!,
          $platform: String,
          $firebase_token_updated_at: timestamptz!
        ) {
          insert_notification_tokens_one(
            object: {user_id: $user_id, token: $token, platform: $platform},
            on_conflict: {
              constraint: notification_tokens_user_id_token_key,
              update_columns: [token, updated_at]
            }
          ) { id }
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
        "platform": "firebase-messaging",
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
        notification_tokens(order_by: {updated_at: desc}) {
          id
          user_id
          token
          platform
          updated_at
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["notification_tokens"] ?? []);
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    const query = r'''
      query GetUserNotifications($user_id: bigint!) {
        user_notifications(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
          id
          title
          body
          created_at
          is_read
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(query: query, variables: {"user_id": userId});
    return List<Map<String, dynamic>>.from(data["user_notifications"] ?? []);
  }

  Future<Map<String, dynamic>?> getNotificationDetail(int id) async {
    const query = r'''
      query GetNotificationDetail($id: bigint!) {
        user_notifications_by_pk(id: $id) {
          id
          title
          body
          created_at
          is_read
        }
      }
    ''';
    final data = await _hasura.graphQLRequest(query: query, variables: {"id": id});
    return data["user_notifications_by_pk"] as Map<String, dynamic>?;
  }

  Future<bool> sendNotification({required String title, required String body, int? userId}) async {
    // Backend tarafında FCM gönderimini tetiklemek için kayıt
    const mutation = r'''
      mutation InsertNotification($title: String!, $body: String!, $user_id: bigint) {
        insert_user_notifications_one(object: {
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
