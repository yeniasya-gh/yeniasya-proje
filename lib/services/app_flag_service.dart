import 'package:flutter/foundation.dart';

import '../models/app_flags.dart';
import 'hasura_manager.dart';

class AppFlagService {
  final _hasura = HasuraManager.instance;

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
      return flags;
    } catch (e) {
      debugPrint("App flags fetch failed: $e");
      return AppFlags.defaults.copyWith(version: version);
    }
  }
}
