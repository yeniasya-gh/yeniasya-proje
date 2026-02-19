import "package:flutter/foundation.dart";

class RevenueCatConfig {
  const RevenueCatConfig._();

  /// Shared fallback key for non-mobile platforms only.
  static const String _sharedApiKey = String.fromEnvironment(
    "REVENUECAT_API_KEY",
    defaultValue: "",
  );

  /// Platform specific SDK public keys.
  static const String apiKeyIos = String.fromEnvironment(
    "REVENUECAT_API_KEY_IOS",
    defaultValue: "appl_sYujQdYfZtAqCLSNkjlledBVrTi",
  );
  static const String apiKeyAndroid = String.fromEnvironment(
    "REVENUECAT_API_KEY_ANDROID",
    defaultValue: "goog_pNZCnlPXPDOwKqKSTnVazUmobYR",
  );

  static String get apiKey {
    if (defaultTargetPlatform == TargetPlatform.iOS) return apiKeyIos;
    if (defaultTargetPlatform == TargetPlatform.android) return apiKeyAndroid;
    final shared = _sharedApiKey.trim();
    if (shared.isNotEmpty) return shared;
    return apiKeyAndroid;
  }

  static bool get isTestApiKey =>
      apiKey.trim().toLowerCase().startsWith("test_");

  static const String entitlementYeniasyaPro = "Yeniasya Pro";

  /// Offering to use in paywall/purchase flows.
  static const String offeringId = String.fromEnvironment(
    "REVENUECAT_OFFERING_ID",
    defaultValue: "default",
  );

  /// Expected custom package identifiers in the selected offering.
  static const String monthlyPackageId = "monthly";
  static const String yearlyPackageId = "yearly";
  static const String lifetimePackageId = "lifetime";

  /// CDN backend sync settings.
  static const String backendBaseUrl = String.fromEnvironment(
    "REVENUECAT_BACKEND_BASE_URL",
    defaultValue: "https://cdn.yeniasyadigital.com",
  );
  static const String backendSyncPath = String.fromEnvironment(
    "REVENUECAT_BACKEND_SYNC_PATH",
    defaultValue: "/revenuecat/subscription/sync",
  );
  static const String backendEventPath = String.fromEnvironment(
    "REVENUECAT_BACKEND_EVENT_PATH",
    defaultValue: "/revenuecat/subscription/event",
  );
}
