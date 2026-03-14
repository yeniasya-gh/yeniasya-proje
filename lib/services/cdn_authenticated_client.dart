import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth/auth_token_store.dart';

class CdnRequestException implements Exception {
  CdnRequestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CdnAuthenticatedClient {
  CdnAuthenticatedClient({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? "https://cdn.yeniasyadigital.com",
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const timeout = Duration(seconds: 30);

  bool get hasToken {
    final token = AuthTokenStore.token?.trim();
    return token != null && token.isNotEmpty;
  }

  int? get currentUserId {
    final token = AuthTokenStore.token?.trim();
    if (token == null || token.isEmpty) return null;

    final parts = token.split(".");
    if (parts.length < 2) return null;

    try {
      final normalized = base64.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is! Map) return null;
      final map = Map<String, dynamic>.from(payload);
      final claims = map["https://hasura.io/jwt/claims"];
      final rawUserId = claims is Map
          ? claims["x-hasura-user-id"] ?? map["sub"]
          : map["sub"];
      return int.tryParse(rawUserId?.toString() ?? "");
    } catch (_) {
      return null;
    }
  }

  bool canReadUserScopedData(int userId) {
    final tokenUserId = currentUserId;
    if (tokenUserId == null) return false;
    return tokenUserId == userId;
  }

  bool shouldFallbackToHasura(Object error) {
    if (error is! CdnRequestException) return true;
    final statusCode = error.statusCode;
    if (statusCode == null) return true;
    return statusCode >= 500;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) async {
    final token = AuthTokenStore.token?.trim();
    if (token == null || token.isEmpty) {
      throw CdnRequestException(
        "Yetkilendirme bulunamadı. Lütfen tekrar giriş yapın.",
        statusCode: 401,
      );
    }

    final uri = Uri.parse("$_baseUrl$path").replace(
      queryParameters: {
        for (final entry in queryParameters.entries)
          if (entry.value != null && entry.value!.trim().isNotEmpty)
            entry.key: entry.value!.trim(),
      },
    );

    late final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              "content-type": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(timeout);
    } catch (error) {
      throw CdnRequestException(error.toString());
    }

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CdnRequestException(
        _responseMessage(body).isNotEmpty
            ? _responseMessage(body)
            : "CDN request failed (${response.statusCode})",
        statusCode: response.statusCode,
      );
    }

    if (body["ok"] == false) {
      throw CdnRequestException(
        _responseMessage(body).isNotEmpty
            ? _responseMessage(body)
            : "CDN request failed.",
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw CdnRequestException("CDN geçersiz yanıt döndürdü.");
  }

  String _responseMessage(Map<String, dynamic> body) {
    final message =
        body["message"]?.toString().trim() ??
        body["error"]?.toString().trim() ??
        body["detail"]?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    final details = body["details"];
    if (details is Map) {
      final detailMessage =
          details["message"]?.toString().trim() ??
          details["hint"]?.toString().trim();
      if (detailMessage != null && detailMessage.isNotEmpty) {
        return detailMessage;
      }
    }
    return "";
  }
}
