import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/payment_config.dart';
import 'auth/auth_token_store.dart';

class PaymentService {
  PaymentService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? PaymentConfig.baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Map<String, String> _authorizedHeaders() {
    final token = AuthTokenStore.token?.trim();
    if (token == null || token.isEmpty) {
      throw const PaymentSessionException(
        "Oturum süresi dolmuş. Lütfen tekrar giriş yapın.",
      );
    }
    return {
      "content-type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  String _extractApiMessage(String body, {required String fallback}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return fallback;

    try {
      final data = jsonDecode(trimmed);
      if (data is Map<String, dynamic>) {
        final message =
            data["error"]?.toString().trim() ??
            data["message"]?.toString().trim() ??
            data["responseMsg"]?.toString().trim() ??
            data["errorMsg"]?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall back to raw body below.
    }

    return trimmed;
  }

  Future<String> createSession({required Map<String, dynamic> payload}) async {
    final uri = Uri.parse("$_baseUrl/payment/session");
    final headers = _authorizedHeaders();
    final resp = await _client
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw PaymentSessionException(
        _extractApiMessage(
          resp.body,
          fallback: "Ödeme oturumu oluşturulamadı (${resp.statusCode}).",
        ),
      );
    }

    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final responseCode = data["paratika"]?["data"]?["responseCode"]
          ?.toString();
      if (responseCode != null &&
          responseCode.isNotEmpty &&
          responseCode != "00") {
        final msg =
            data["paratika"]?["data"]?["errorMsg"]?.toString() ??
            data["paratika"]?["data"]?["responseMsg"]?.toString() ??
            "Session reddedildi.";
        throw PaymentSessionException(msg);
      }
      final token = data["paratika"]?["data"]?["sessionToken"]?.toString();
      if (token == null || token.isEmpty) {
        throw PaymentSessionException("Session token bos dondu.");
      }
      return token;
    } on FormatException catch (e) {
      throw PaymentSessionException("Session yaniti cozulmedi: $e");
    }
  }

  Future<List<SavedCard>> queryCards({required String customer}) async {
    final uri = Uri.parse("$_baseUrl/payment/query-card");

    final headers = _authorizedHeaders();
    final resp = await _client
        .post(uri, headers: headers, body: jsonEncode({"customer": customer}))
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw PaymentSessionException(
        _extractApiMessage(
          resp.body,
          fallback: "Kayıtlı kartlar alınamadı (${resp.statusCode}).",
        ),
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final responseCode = data["responseCode"]?.toString();
    if (responseCode != null &&
        responseCode.isNotEmpty &&
        responseCode != "00") {
      final msg =
          data["errorMsg"]?.toString() ??
          data["responseMsg"]?.toString() ??
          "Kayıtlı kartlar alınamadı.";
      throw PaymentSessionException(msg);
    }

    final list = (data["cardList"] as List<dynamic>? ?? const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => SavedCard.fromJson(json))
        .toList(growable: false);
  }

  Future<void> deleteCard({required String cardToken}) async {
    final uri = Uri.parse("$_baseUrl/payment/delete-card");

    final headers = _authorizedHeaders();
    final resp = await _client
        .post(uri, headers: headers, body: jsonEncode({"cardToken": cardToken}))
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw PaymentSessionException(
        _extractApiMessage(
          resp.body,
          fallback: "Kart silinemedi (${resp.statusCode}).",
        ),
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final responseCode = data["responseCode"]?.toString();
    if (responseCode != "00") {
      final msg = data["responseMsg"]?.toString() ?? "Kart silinemedi.";
      throw PaymentSessionException(msg);
    }
  }

  Uri redirectUri() => Uri.parse("$_baseUrl/payment/pay/redirect");
}

class PaymentSessionException implements Exception {
  final String message;

  const PaymentSessionException(this.message);

  @override
  String toString() => message;
}

class SavedCard {
  final String cardToken;
  final String? cardOwner;
  final String? panLast4;
  final String? cardBrand;
  final String? cardType;
  final String? cardNetwork;
  final String? cardExpiry;
  final String? cardName;
  final String? panMasked;

  const SavedCard({
    required this.cardToken,
    this.cardOwner,
    this.panLast4,
    this.cardBrand,
    this.cardType,
    this.cardNetwork,
    this.cardExpiry,
    this.cardName,
    this.panMasked,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      cardToken: json["cardToken"]?.toString() ?? "",
      cardOwner: json["cardOwner"]?.toString(),
      panLast4: json["panLast4"]?.toString(),
      cardBrand: json["cardBrand"]?.toString(),
      cardType: json["cardType"]?.toString(),
      cardNetwork: json["cardNetwork"]?.toString(),
      cardExpiry: json["cardExpiry"]?.toString(),
      cardName: json["cardName"]?.toString(),
      panMasked: json["pan"]?.toString(),
    );
  }
}

class PaymentRedirectPayload {
  final String sessionToken;
  final String? cardPan;
  final String? cardExpiry;
  final String? cardCvv;
  final String? nameOnCard;
  final bool saveCard;
  final String? cardName;
  final String? cardToken;

  const PaymentRedirectPayload({
    required this.sessionToken,
    this.cardPan,
    this.cardExpiry,
    this.cardCvv,
    this.nameOnCard,
    this.saveCard = false,
    this.cardName,
    this.cardToken,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{"SESSIONTOKEN": sessionToken};

    if (cardToken != null && cardToken!.isNotEmpty) {
      json["CARDTOKEN"] = cardToken;
    } else {
      if (cardPan != null) json["CARDPAN"] = cardPan;
      if (cardExpiry != null) json["CARDEXPIRY"] = cardExpiry;
      if (cardCvv != null) json["CARDCVV"] = cardCvv;
      if (nameOnCard != null) json["NAMEONCARD"] = nameOnCard;
      json["SAVECARD"] = saveCard ? "YES" : "NO";

      if (saveCard) {
        final name = cardName?.trim();
        if (name != null && name.isNotEmpty) {
          json["CARDNAME"] = name;
        }
      }
    }

    return json;
  }
}
