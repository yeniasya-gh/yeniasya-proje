import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_token_store.dart';

class AuthApiService {
  AuthApiService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? "https://cdn.yeniasyadigital.com",
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/register");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        if (phone != null) "phone": phone,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("Register failed (${resp.statusCode}): ${resp.body}");
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data["ok"] != true) {
      throw Exception(data["message"]?.toString() ?? "Register failed");
    }
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/login");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({"email": email, "password": password}),
    );

    if (resp.statusCode == 401) {
      throw Exception("INVALID_CREDENTIALS");
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("Login failed (${resp.statusCode}): ${resp.body}");
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data["ok"] != true) {
      throw Exception(data["message"]?.toString() ?? "Login failed");
    }
    return data;
  }

  Future<Map<String, dynamic>> socialLogin({
    required String email,
    required String provider,
    String? name,
    String? phone,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/social-login");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        "email": email,
        "provider": provider,
        if (name != null && name.trim().isNotEmpty) "name": name.trim(),
        if (phone != null && phone.trim().isNotEmpty) "phone": phone.trim(),
      }),
    );

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (resp.statusCode == 404 &&
        payload?["error"]?.toString() == "USER_NOT_FOUND") {
      throw Exception("SOCIAL_USER_NOT_FOUND");
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("SOCIAL_LOGIN_FAILED (${resp.statusCode}): ${resp.body}");
    }
    final data = payload ?? (jsonDecode(resp.body) as Map<String, dynamic>);
    if (data["ok"] != true) {
      throw Exception(
        data["error"]?.toString() ??
            data["message"]?.toString() ??
            "SOCIAL_LOGIN_FAILED",
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> guestToken() async {
    final uri = Uri.parse("$_baseUrl/auth/guest-token");
    final headers = {"content-type": "application/json"};
    final resp = await _client.post(
      uri,
      headers: headers,
      body: "{}",
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("Guest token failed (${resp.statusCode}): ${resp.body}");
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data["ok"] != true) {
      throw Exception(data["message"]?.toString() ?? "Guest token failed");
    }
    return data;
  }

  Future<void> requestPasswordReset({required String email}) async {
    final uri = Uri.parse("$_baseUrl/auth/password-reset/request");
    final resp = await _client.post(
      uri,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({"email": email.trim()}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    throw Exception(_requestPasswordResetError(resp));
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/password-reset/confirm");
    final resp = await _client.post(
      uri,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({
        "token": token.trim(),
        "password": newPassword,
      }),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    throw Exception(_confirmPasswordResetError(resp));
  }

  Future<String> getNewspaperViewUrl({required DateTime date}) async {
    final uri = Uri.parse("$_baseUrl/newspaper/view-url");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final dateOnly = date.toUtc().toIso8601String().split("T").first;
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({"date": dateOnly}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_newspaperViewUrlError(resp));
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = data["url"]?.toString().trim() ?? "";
    if (data["ok"] != true || url.isEmpty) {
      throw Exception("E-gazete bağlantısı alınamadı.");
    }
    return url;
  }

  String _requestPasswordResetError(http.Response resp) {
    final message = _responseMessage(resp);
    switch (resp.statusCode) {
      case 404:
        return "Şifre sıfırlama servisi henüz aktif değil.";
      case 429:
        return "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.";
      default:
        return message.isNotEmpty
            ? message
            : "Şifre sıfırlama isteği gönderilemedi.";
    }
  }

  String _confirmPasswordResetError(http.Response resp) {
    final message = _responseMessage(resp);
    switch (resp.statusCode) {
      case 400:
      case 401:
        return message.isNotEmpty
            ? message
            : "Sıfırlama bağlantısı geçersiz veya kullanılmış.";
      case 410:
        return message.isNotEmpty
            ? message
            : "Sıfırlama bağlantısının süresi dolmuş.";
      case 404:
        return "Şifre sıfırlama servisi henüz aktif değil.";
      case 429:
        return "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.";
      default:
        return message.isNotEmpty ? message : "Şifre güncellenemedi.";
    }
  }

  String _newspaperViewUrlError(http.Response resp) {
    final message = _responseMessage(resp);
    switch (resp.statusCode) {
      case 400:
        return message.isNotEmpty ? message : "Geçerli bir gazete tarihi seçin.";
      case 401:
        return "Gazeteyi görüntülemek için yeniden giriş yapın.";
      case 403:
        return message.isNotEmpty
            ? message
            : "Aktif e-gazete aboneliğiniz bulunmuyor.";
      case 404:
        return "E-gazete görüntüleme servisi bulunamadı.";
      case 503:
        return message.isNotEmpty
            ? message
            : "E-gazete servisi şu anda kullanılamıyor.";
      default:
        return message.isNotEmpty
            ? message
            : "E-gazete bağlantısı alınamadı.";
    }
  }

  String _responseMessage(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded["message"]?.toString().trim() ??
            decoded["error"]?.toString().trim() ??
            decoded["detail"]?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore non-JSON bodies and fall back to a generic message.
    }
    return "";
  }
}
