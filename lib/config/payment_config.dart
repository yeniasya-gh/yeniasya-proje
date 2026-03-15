import 'package:flutter/foundation.dart';

class PaymentConfig {
  static const baseUrl = "https://cdn.yeniasyadijital.com";
  static const apiKey = "kPPm8b-12kA-9PxQ-YY822L";
  static const returnUrl = "https://cdn.yeniasyadijital.com/payment/return";

  static String resolveReturnUrl() {
    if (!kIsWeb) return returnUrl;
    final origin = Uri.base.origin;
    final query = Uri(queryParameters: {"appReturnOrigin": origin}).query;
    return "$returnUrl?$query";
  }
}
