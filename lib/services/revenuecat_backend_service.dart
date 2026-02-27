import "dart:convert";

import "package:http/http.dart" as http;

import "../config/revenuecat_config.dart";
import "auth/auth_token_store.dart";

class RevenueCatBackendService {
  RevenueCatBackendService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? RevenueCatConfig.backendBaseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<void> syncSubscription({
    required String source,
    required String entitlementId,
    required bool isActive,
    String? appUserId,
    String? expectedAppUserId,
    bool? identityMatched,
    int? userId,
    String? productIdentifier,
    String? expirationDate,
    List<String>? activeSubscriptions,
    Map<String, dynamic>? customerInfoRaw,
  }) async {
    final payload = <String, dynamic>{
      "source": source,
      "entitlementId": entitlementId,
      "isActive": isActive,
      if (appUserId != null && appUserId.isNotEmpty) "appUserId": appUserId,
      if (expectedAppUserId != null && expectedAppUserId.isNotEmpty)
        "expectedAppUserId": expectedAppUserId,
      if (identityMatched != null) "identityMatched": identityMatched,
      if (userId != null) "userId": userId,
      if (productIdentifier != null && productIdentifier.isNotEmpty)
        "productIdentifier": productIdentifier,
      if (expirationDate != null && expirationDate.isNotEmpty)
        "expirationDate": expirationDate,
      if (activeSubscriptions != null)
        "activeSubscriptions": activeSubscriptions,
      if (customerInfoRaw != null) "customerInfo": customerInfoRaw,
    };
    await _post(RevenueCatConfig.backendSyncPath, payload);
  }

  Future<void> reportPaywallEvent({
    required String source,
    required String entitlementId,
    required String result,
    required bool success,
    String? message,
    String? appUserId,
    String? expectedAppUserId,
    bool? identityMatched,
    int? userId,
    List<String>? productIdentifiers,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      "source": source,
      "entitlementId": entitlementId,
      "result": result,
      "success": success,
      if (message != null && message.isNotEmpty) "message": message,
      if (appUserId != null && appUserId.isNotEmpty) "appUserId": appUserId,
      if (expectedAppUserId != null && expectedAppUserId.isNotEmpty)
        "expectedAppUserId": expectedAppUserId,
      if (identityMatched != null) "identityMatched": identityMatched,
      if (userId != null) "userId": userId,
      if (productIdentifiers != null) "productIdentifiers": productIdentifiers,
      if (metadata != null) "metadata": metadata,
    };
    await _post(RevenueCatConfig.backendEventPath, payload);
  }

  Future<Map<String, dynamic>> refreshSubscription({
    String source = "manual_refresh",
    String? entitlementId,
    String? appUserId,
    String? expectedAppUserId,
    bool? identityMatched,
    int? userId,
    bool? isActive,
    String? expirationDate,
  }) {
    final payload = <String, dynamic>{
      "source": source,
      if (entitlementId != null && entitlementId.isNotEmpty)
        "entitlementId": entitlementId,
      if (appUserId != null && appUserId.isNotEmpty) "appUserId": appUserId,
      if (expectedAppUserId != null && expectedAppUserId.isNotEmpty)
        "expectedAppUserId": expectedAppUserId,
      if (identityMatched != null) "identityMatched": identityMatched,
      if (userId != null) "userId": userId,
      if (isActive != null) "isActive": isActive,
      if (expirationDate != null && expirationDate.isNotEmpty)
        "expirationDate": expirationDate,
    };
    return _post(RevenueCatConfig.backendRefreshPath, payload);
  }

  Future<Map<String, dynamic>> grantSubscription({
    String source = "web_checkout",
    String? entitlementId,
    String? appUserId,
    String? expectedAppUserId,
    bool? identityMatched,
    int? userId,
    String? expirationDate,
    int? durationMonths,
    bool lifetime = false,
    String? platform,
  }) {
    final payload = <String, dynamic>{
      "source": source,
      if (entitlementId != null && entitlementId.isNotEmpty)
        "entitlementId": entitlementId,
      if (appUserId != null && appUserId.isNotEmpty) "appUserId": appUserId,
      if (expectedAppUserId != null && expectedAppUserId.isNotEmpty)
        "expectedAppUserId": expectedAppUserId,
      if (identityMatched != null) "identityMatched": identityMatched,
      if (userId != null) "userId": userId,
      if (expirationDate != null && expirationDate.isNotEmpty)
        "expirationDate": expirationDate,
      if (durationMonths != null && durationMonths > 0)
        "durationMonths": durationMonths,
      if (lifetime) "lifetime": true,
      if (platform != null && platform.isNotEmpty) "platform": platform,
    };
    return _post(RevenueCatConfig.backendGrantPath, payload);
  }

  Future<Map<String, dynamic>> revokeSubscription({
    String source = "manual_revoke",
    String? entitlementId,
    String? appUserId,
    String? expectedAppUserId,
    bool? identityMatched,
    int? userId,
  }) {
    final payload = <String, dynamic>{
      "source": source,
      if (entitlementId != null && entitlementId.isNotEmpty)
        "entitlementId": entitlementId,
      if (appUserId != null && appUserId.isNotEmpty) "appUserId": appUserId,
      if (expectedAppUserId != null && expectedAppUserId.isNotEmpty)
        "expectedAppUserId": expectedAppUserId,
      if (identityMatched != null) "identityMatched": identityMatched,
      if (userId != null) "userId": userId,
    };
    return _post(RevenueCatConfig.backendRevokePath, payload);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse("$_baseUrl$path");
    final headers = <String, String>{
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "authorization": "Bearer ${AuthTokenStore.token}",
    };

    final response = await _client
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        "RevenueCat backend request failed (${response.statusCode}): ${response.body}",
      );
    }

    final trimmed = response.body.trim();
    if (trimmed.isEmpty) return const {};
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return const {};
  }
}
