class PurchaseChannelLabels {
  const PurchaseChannelLabels._();

  static String accessChannelLabel(Map<String, dynamic> item) {
    final purchasePlatform = _normalize(
      item["purchase_platform"] ?? item["purchasePlatform"],
    );
    if (purchasePlatform != null) {
      return purchasePlatformLabel(purchasePlatform);
    }

    final grantSource = _normalize(item["grant_source"] ?? item["grantSource"]);
    if (grantSource != null) {
      switch (grantSource) {
        case "revenuecat":
          return "RevenueCat";
        case "manual_newspaper":
          return _manualNewspaperLabel(item);
      }
      return _humanize(grantSource);
    }

    final source = _normalize(item["source"]);
    if (source == "manual_newspaper") {
      return _manualNewspaperLabel(item);
    }

    final paymentProvider = _normalize(
      item["payment_provider"] ?? item["paymentProvider"],
    );
    if (paymentProvider != null) {
      return paymentProviderLabel(paymentProvider);
    }

    return "Bilinmiyor";
  }

  static String purchasePlatformLabel(dynamic raw) {
    final normalized = _normalize(raw);
    if (normalized == null) return "Bilinmiyor";
    switch (normalized) {
      case "apple":
      case "app_store":
      case "appstore":
      case "mac_app_store":
      case "macappstore":
        return "Apple";
      case "google_play":
      case "googleplay":
      case "play_store":
      case "playstore":
        return "Google Play";
      case "paratika":
      case "sanal_pos":
      case "virtual_pos":
        return "Paratika (Sanal POS)";
      case "revenuecat":
        return "RevenueCat";
      case "stripe":
        return "Stripe";
      case "amazon":
        return "Amazon";
      case "rc_billing":
        return "RevenueCat Billing";
      case "paddle":
        return "Paddle";
      case "test_store":
      case "teststore":
        return "Test Store";
      case "external_store":
      case "externalstore":
        return "External Store";
      case "unknown_store":
      case "unknownstore":
        return "Bilinmiyor";
      default:
        return _humanize(normalized);
    }
  }

  static String paymentProviderLabel(dynamic raw) {
    final normalized = _normalize(raw);
    if (normalized == null) return "Bilinmiyor";
    switch (normalized) {
      case "paratika":
      case "sanal_pos":
      case "virtual_pos":
        return "Paratika (Sanal POS)";
      case "apple":
      case "app_store":
      case "appstore":
        return "Apple";
      case "google_play":
      case "googleplay":
      case "play_store":
      case "playstore":
        return "Google Play";
      default:
        return _humanize(normalized);
    }
  }

  static String _manualNewspaperLabel(Map<String, dynamic> item) {
    final status = _normalize(
      item["status"] ??
          item["source_status"] ??
          item["manual_status"] ??
          item["record_status"],
    );
    if (status == "old" || status == "eski") {
      return "Manuel (Eski)";
    }
    if (status == "new" || status == "yeni") {
      return "Manuel (Yeni)";
    }
    return "Manuel";
  }

  static String orderChannelLabel(Map<String, dynamic> item) {
    final purchasePlatform = _normalize(
      item["purchase_platform"] ?? item["purchasePlatform"],
    );
    if (purchasePlatform != null) {
      switch (purchasePlatform) {
        case "paratika":
        case "sanal_pos":
        case "virtual_pos":
        case "web_checkout":
        case "web":
        case "checkout":
          return "Web";
        case "apple":
        case "app_store":
        case "appstore":
        case "ios":
        case "iphone":
        case "mac_app_store":
        case "macappstore":
          return "iOS / Apple";
        case "google_play":
        case "googleplay":
        case "play_store":
        case "playstore":
        case "android":
          return "Android / Google Play";
        default:
          return purchasePlatformLabel(purchasePlatform);
      }
    }

    final paymentProvider = _normalize(
      item["payment_provider"] ?? item["paymentProvider"],
    );
    if (paymentProvider != null) {
      switch (paymentProvider) {
        case "paratika":
        case "sanal_pos":
        case "virtual_pos":
        case "web_checkout":
        case "web":
        case "checkout":
          return "Web";
        case "apple":
        case "app_store":
        case "appstore":
        case "ios":
        case "iphone":
        case "mac_app_store":
        case "macappstore":
          return "iOS / Apple";
        case "google_play":
        case "googleplay":
        case "play_store":
        case "playstore":
        case "android":
          return "Android / Google Play";
        default:
          return _humanize(paymentProvider);
      }
    }

    final merchantPaymentId = _normalize(
      item["merchant_payment_id"] ?? item["merchantPaymentId"],
    );
    final paymentSessionToken = _normalize(
      item["payment_session_token"] ?? item["paymentSessionToken"],
    );
    if (merchantPaymentId != null || paymentSessionToken != null) {
      return "Web";
    }

    final source = _normalize(item["source"]);
    if (source == "web_checkout") {
      return "Web";
    }

    return "Bilinmiyor";
  }

  static String _humanize(String value) {
    final parts = value
        .replaceAll("_", " ")
        .split(RegExp(r"\s+"))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length <= 1) return part.toUpperCase();
          return part[0].toUpperCase() + part.substring(1);
        })
        .toList(growable: false);
    return parts.isEmpty ? "Bilinmiyor" : parts.join(" ");
  }

  static String? _normalize(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    return text.replaceAll(RegExp(r"[\s-]+"), "_");
  }
}
