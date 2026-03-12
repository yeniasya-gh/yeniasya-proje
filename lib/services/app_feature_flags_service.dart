import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'hasura_manager.dart';

class AppFeatureVisibility {
  final bool hideMagazines;
  final bool hideNewspapers;
  final String appVersion;
  final String appBuildNumber;
  final String? configuredVersion;

  const AppFeatureVisibility({
    this.hideMagazines = false,
    this.hideNewspapers = false,
    this.appVersion = "",
    this.appBuildNumber = "",
    this.configuredVersion,
  });
}

class AppFeatureFlagsService {
  final _hasura = HasuraManager.instance;

  Future<AppFeatureVisibility> getVisibilityForCurrentApp() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version.trim();
    final appBuildNumber = packageInfo.buildNumber.trim();

    // Web platform intentionally ignores app_feature_flags controls.
    if (kIsWeb) {
      return AppFeatureVisibility(
        appVersion: appVersion,
        appBuildNumber: appBuildNumber,
      );
    }

    final int? flagId = switch (defaultTargetPlatform) {
      TargetPlatform.android => 1,
      TargetPlatform.iOS => 2,
      _ => null,
    };

    if (flagId == null) {
      return AppFeatureVisibility(
        appVersion: appVersion,
        appBuildNumber: appBuildNumber,
      );
    }

    final query =
        '''
      query GetAppFeatureFlags {
        app_feature_flags(where: {id: {_eq: $flagId}}, limit: 1) {
          id
          version
          hide_magazines
          hide_newspapers
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      timeout: HasuraManager.homeTimeout,
    );
    final rawItems = data["app_feature_flags"];
    if (rawItems is! List || rawItems.isEmpty) {
      return AppFeatureVisibility(
        appVersion: appVersion,
        appBuildNumber: appBuildNumber,
      );
    }

    final first = rawItems.first;
    if (first is! Map) {
      return AppFeatureVisibility(
        appVersion: appVersion,
        appBuildNumber: appBuildNumber,
      );
    }

    final row = Map<String, dynamic>.from(first);
    final configuredVersion = (row["version"] ?? "").toString().trim();
    final versionMatched = _matchesConfiguredVersion(
      configuredVersion: configuredVersion,
      appVersion: appVersion,
      appBuildNumber: appBuildNumber,
    );

    return AppFeatureVisibility(
      hideMagazines: versionMatched ? _toBool(row["hide_magazines"]) : false,
      hideNewspapers: versionMatched ? _toBool(row["hide_newspapers"]) : false,
      appVersion: appVersion,
      appBuildNumber: appBuildNumber,
      configuredVersion: configuredVersion.isEmpty ? null : configuredVersion,
    );
  }

  bool _matchesConfiguredVersion({
    required String configuredVersion,
    required String appVersion,
    required String appBuildNumber,
  }) {
    final configured = configuredVersion.trim().toLowerCase();
    final appCore = appVersion.trim().toLowerCase();
    final appBuild = appBuildNumber.trim().toLowerCase();
    if (configured.isEmpty || appCore.isEmpty) return false;

    final appFull = appBuild.isEmpty ? appCore : "$appCore+$appBuild";
    if (configured.contains("+")) {
      return configured == appFull;
    }
    return configured == appCore;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return false;
    return text == "true" ||
        text == "1" ||
        text == "t" ||
        text == "yes" ||
        text == "y";
  }
}
