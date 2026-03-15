import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  AppFeatureFlagsService({String? baseUrl, http.Client? client})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            "CDN_BASE_URL",
            defaultValue: "https://cdn.yeniasyadijital.com",
          ),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const _cdnTimeout = Duration(seconds: 5);

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

    final row = await _getFeatureFlagRow(flagId);
    if (row == null) {
      return AppFeatureVisibility(
        appVersion: appVersion,
        appBuildNumber: appBuildNumber,
      );
    }
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

  Future<Map<String, dynamic>?> _getFeatureFlagRow(int flagId) async {
    try {
      return await _getFeatureFlagRowFromCdn(flagId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getFeatureFlagRowFromCdn(int flagId) async {
    final uri = Uri.parse(
      "$_baseUrl/app/feature-flags",
    ).replace(queryParameters: {"id": "$flagId"});
    final response = await _client.get(uri).timeout(_cdnTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("APP_FEATURE_FLAGS_HTTP_${response.statusCode}");
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception("APP_FEATURE_FLAGS_INVALID_PAYLOAD");
    }
    final body = Map<String, dynamic>.from(decoded);
    if (body["ok"] == false) {
      throw Exception(
        body["error"]?.toString() ?? "APP_FEATURE_FLAGS_REQUEST_FAILED",
      );
    }

    final data = body["data"];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
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
