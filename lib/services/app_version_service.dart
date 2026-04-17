import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionGate {
  final bool forceUpdateRequired;
  final String currentVersion;
  final String currentBuildNumber;
  final String? requiredVersion;
  final String platformKey;
  final String storeUrl;

  const AppVersionGate({
    required this.forceUpdateRequired,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.requiredVersion,
    required this.platformKey,
    required this.storeUrl,
  });

  const AppVersionGate.none({
    required String currentVersion,
    required String currentBuildNumber,
  }) : this(
         forceUpdateRequired: false,
         currentVersion: currentVersion,
         currentBuildNumber: currentBuildNumber,
         requiredVersion: null,
         platformKey: "",
         storeUrl: "",
       );
}

class AppVersionService {
  AppVersionService({String? baseUrl, http.Client? client})
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

  Future<AppVersionGate> getGateForCurrentApp() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final currentBuildNumber = packageInfo.buildNumber.trim();

    if (kIsWeb) {
      return AppVersionGate.none(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    }

    final platformKey = switch (defaultTargetPlatform) {
      TargetPlatform.android => "android",
      TargetPlatform.iOS => "ios",
      _ => "",
    };

    if (platformKey.isEmpty) {
      return AppVersionGate.none(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    }

    try {
      final row = await _getVersionRow(platformKey);
      if (row == null) {
        return AppVersionGate.none(
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }

      final requiredVersion = (row["value"] ?? "").toString().trim();
      final forceUpdateRequired =
          requiredVersion.isNotEmpty &&
          isForceUpdateRequired(
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            requiredVersion: requiredVersion,
          );

      return AppVersionGate(
        forceUpdateRequired: forceUpdateRequired,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        requiredVersion: requiredVersion.isEmpty ? null : requiredVersion,
        platformKey: platformKey,
        storeUrl: _storeUrlForPlatform(platformKey),
      );
    } catch (_) {
      return AppVersionGate.none(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    }
  }

  Future<Map<String, dynamic>?> _getVersionRow(String platformKey) async {
    final uri = Uri.parse(
      "$_baseUrl/app/version",
    ).replace(queryParameters: {"platform": platformKey});
    final response = await _client.get(uri).timeout(_cdnTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("APP_VERSION_HTTP_${response.statusCode}");
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception("APP_VERSION_INVALID_PAYLOAD");
    }
    final body = Map<String, dynamic>.from(decoded);
    if (body["ok"] == false) {
      throw Exception(
        body["error"]?.toString() ?? "APP_VERSION_REQUEST_FAILED",
      );
    }

    final data = body["data"];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  static bool isForceUpdateRequired({
    required String currentVersion,
    required String currentBuildNumber,
    required String requiredVersion,
  }) {
    final required = requiredVersion.trim();
    if (required.isEmpty) return false;
    return compareVersions(
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          requiredVersion: required,
        ) <
        0;
  }

  static int compareVersions({
    required String currentVersion,
    required String currentBuildNumber,
    required String requiredVersion,
  }) {
    final currentParts = _versionParts(
      version: currentVersion,
      buildNumber: currentBuildNumber,
      includeBuild: requiredVersion.contains("+"),
    );
    final requiredParts = _versionParts(
      version: requiredVersion,
      buildNumber: null,
      includeBuild: requiredVersion.contains("+"),
    );

    final maxLength = currentParts.length > requiredParts.length
        ? currentParts.length
        : requiredParts.length;
    for (var i = 0; i < maxLength; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final requiredPart = i < requiredParts.length ? requiredParts[i] : 0;
      if (currentPart != requiredPart) {
        return currentPart.compareTo(requiredPart);
      }
    }
    return 0;
  }

  static List<int> _versionParts({
    required String version,
    required String? buildNumber,
    required bool includeBuild,
  }) {
    final core = version.trim().split('+').first.split('-').first.trim();
    final parts = core
        .split('.')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }

    if (includeBuild) {
      final explicitBuild = buildNumber?.trim();
      final sourceBuild = explicitBuild != null && explicitBuild.isNotEmpty
          ? explicitBuild
          : (version.contains('+') ? version.split('+').last.trim() : "0");
      parts.add(int.tryParse(sourceBuild) ?? 0);
    }

    return parts;
  }

  String _storeUrlForPlatform(String platformKey) {
    switch (platformKey) {
      case "android":
        return "https://play.google.com/store/apps/details?id=com.yeniasya.books";
      case "ios":
        return "https://apps.apple.com/tr/app/yeni-asya-dijital/id6758656907?l=tr";
      default:
        return "https://yeniasyadijital.com";
    }
  }
}
