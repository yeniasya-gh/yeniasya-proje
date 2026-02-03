import 'package:flutter/foundation.dart';

import '../models/app_flags.dart';
import 'auth/auth_api_service.dart';
import 'auth/auth_token_store.dart';
import 'hasura_manager.dart';

class AppFlagService {
  final _hasura = HasuraManager.instance;
  final _authApi = AuthApiService();

  Future<AppFlags> fetchFlags({required String version}) async {
    const query = r'''
      query GetAppFlags {
        app_feature_flags(
          order_by: {created_at: desc},
          limit: 1
        ) {
          version
          hide_magazines
          hide_newspapers
        }
      }
    ''';

    try {
      final data = await _hasura.graphQLRequest(
        query: query,
      );
      final rows = List<Map<String, dynamic>>.from(
        data["app_feature_flags"] ?? [],
      );
      if (rows.isEmpty) return AppFlags.defaults.copyWith(version: version);
      final flags = AppFlags.fromMap(rows.first);
      if (flags.hideMagazines && flags.hideNewspapers) {
        await _ensureGuestToken();
      }
      return flags;
    } catch (e) {
      debugPrint("App flags fetch failed: $e");
      return AppFlags.defaults.copyWith(version: version);
    }
  }

  Future<void> _ensureGuestToken() async {
    if (AuthTokenStore.token != null && !AuthTokenStore.isExpired) return;
    try {
      final data = await _authApi.guestToken();
      final token = data["token"]?.toString();
      final rawExp = data["expiresAt"]?.toString();
      if (token == null || token.isEmpty) return;
      final expiresAt = rawExp != null && rawExp.isNotEmpty
          ? DateTime.parse(rawExp)
          : DateTime.now().add(const Duration(days: 1));
      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
    } catch (e) {
      debugPrint("Guest token failed: $e");
    }
  }
}
