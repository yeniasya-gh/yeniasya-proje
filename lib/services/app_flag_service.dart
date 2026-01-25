import 'package:flutter/foundation.dart';

import '../models/app_flags.dart';
import 'hasura_manager.dart';

class AppFlagService {
  final _hasura = HasuraManager.instance;

  Future<AppFlags> fetchFlags({required String version}) async {
    const query = r'''
      query GetAppFlags($version: String!) {
        app_feature_flags(
          where: {version: {_eq: $version}},
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
        variables: {"version": version},
      );
      final rows = List<Map<String, dynamic>>.from(
        data["app_feature_flags"] ?? [],
      );
      if (rows.isEmpty) return AppFlags.defaults.copyWith(version: version);
      return AppFlags.fromMap(rows.first);
    } catch (e) {
      debugPrint("App flags fetch failed: $e");
      return AppFlags.defaults.copyWith(version: version);
    }
  }
}
