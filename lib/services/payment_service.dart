import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/payment_config.dart';

class PaymentService {
  PaymentService({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? PaymentConfig.baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<String> createSession({required Map<String, dynamic> payload}) async {
    final uri = Uri.parse("$_baseUrl/payment/session");
    // ignore: avoid_print
    print("🟦 PaymentService.createSession -> $uri");
    // ignore: avoid_print
    print("🟦 Payment payload: ${jsonEncode(payload)}");
    final resp = await _client
        .post(
          uri,
          headers: {
            "content-type": "application/json",
            "x-api-key": PaymentConfig.apiKey,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    // ignore: avoid_print
    print("🟩 Payment session response (${resp.statusCode}): ${resp.body}");

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("Session token alinmadi (${resp.statusCode}): ${resp.body}");
    }

    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final responseCode = data["paratika"]?["data"]?["responseCode"]?.toString();
      if (responseCode != null && responseCode.isNotEmpty && responseCode != "00") {
        final msg = data["paratika"]?["data"]?["responseMsg"]?.toString() ?? "Session reddedildi.";
        throw Exception(msg);
      }
      final token = data["paratika"]?["data"]?["sessionToken"]?.toString();
      if (token == null || token.isEmpty) {
        throw Exception("Session token bos dondu.");
      }
      return token;
    } catch (e) {
      throw Exception("Session yaniti cozulmedi: $e");
    }
  }

  Uri redirectUri() => Uri.parse("$_baseUrl/payment/pay/redirect");
}

class PaymentRedirectPayload {
  final String sessionToken;
  final String cardPan;
  final String cardExpiry;
  final String cardCvv;
  final String nameOnCard;

  const PaymentRedirectPayload({
    required this.sessionToken,
    required this.cardPan,
    required this.cardExpiry,
    required this.cardCvv,
    required this.nameOnCard,
  });

  Map<String, dynamic> toJson() => {
        "SESSIONTOKEN": sessionToken,
        "CARDPAN": cardPan,
        "CARDEXPIRY": cardExpiry,
        "CARDCVV": cardCvv,
        "NAMEONCARD": nameOnCard,
      };
}
