import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_token_store.dart';

class AuthApiService {
  AuthApiService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? "https://cdn.yeniasyadijital.com",
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

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
        "email": _normalizeEmail(email),
        "password": password,
        if (phone != null) "phone": phone,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_registerError(resp));
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
      body: jsonEncode({"email": _normalizeEmail(email), "password": password}),
    );

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (resp.statusCode == 429) {
      throw Exception(
        "Çok fazla giriş denemesi yapıldı. Lütfen biraz sonra tekrar deneyin.",
      );
    }
    if (resp.statusCode == 401) {
      throw Exception("INVALID_CREDENTIALS");
    }
    if (resp.statusCode == 403 &&
        payload?["code"]?.toString() == "EMAIL_NOT_VERIFIED") {
      throw Exception("EMAIL_NOT_VERIFIED");
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        _responseMessage(resp).isNotEmpty
            ? _responseMessage(resp)
            : "Login failed (${resp.statusCode})",
      );
    }
    final data = payload ?? (jsonDecode(resp.body) as Map<String, dynamic>);
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
        "email": _normalizeEmail(email),
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

  Future<Map<String, dynamic>> socialRegister({
    required String email,
    required String name,
    required String provider,
    String? phone,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/social-register");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        "email": _normalizeEmail(email),
        "name": name,
        "provider": provider,
        if (phone != null && phone.trim().isNotEmpty) "phone": phone.trim(),
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        _responseMessage(resp).isNotEmpty
            ? _responseMessage(resp)
            : "SOCIAL_REGISTER_FAILED (${resp.statusCode})",
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data["ok"] != true) {
      throw Exception(
        data["error"]?.toString() ??
            data["message"]?.toString() ??
            "SOCIAL_REGISTER_FAILED",
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> guestToken() async {
    final uri = Uri.parse("$_baseUrl/auth/guest-token");
    final headers = {"content-type": "application/json"};
    final resp = await _client.post(uri, headers: headers, body: "{}");
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
      body: jsonEncode({"email": _normalizeEmail(email)}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    throw Exception(_requestPasswordResetError(resp));
  }

  Future<void> requestEmailVerification({required String email}) async {
    final uri = Uri.parse("$_baseUrl/auth/email-verification/request");
    final resp = await _client.post(
      uri,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({"email": _normalizeEmail(email)}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    throw Exception(_requestEmailVerificationError(resp));
  }

  Future<void> confirmEmailVerification({required String token}) async {
    final uri = Uri.parse("$_baseUrl/auth/email-verification/confirm");
    final resp = await _client.post(
      uri,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({"token": token.trim()}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    throw Exception(_confirmEmailVerificationError(resp));
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/password-reset/confirm");
    final resp = await _client.post(
      uri,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({"token": token.trim(), "password": newPassword}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    throw Exception(_confirmPasswordResetError(resp));
  }

  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse("$_baseUrl/auth/me");
    final resp = await _client.get(uri, headers: _authorizedJsonHeaders());
    return _parseUserResponse(
      resp,
      fallbackMessage: "Kullanıcı bilgisi alınamadı.",
    );
  }

  Future<Map<String, dynamic>> updateMe({
    required String name,
    String? phone,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/me");
    final resp = await _client.patch(
      uri,
      headers: _authorizedJsonHeaders(),
      body: jsonEncode({
        "name": name.trim(),
        "phone": phone?.trim().isEmpty == true ? null : phone?.trim(),
      }),
    );
    return _parseUserResponse(resp, fallbackMessage: "Profil güncellenemedi.");
  }

  Future<Map<String, dynamic>> updateAvatar({required String avatarUrl}) async {
    final uri = Uri.parse("$_baseUrl/auth/me/avatar");
    final resp = await _client.put(
      uri,
      headers: _authorizedJsonHeaders(),
      body: jsonEncode({"avatarUrl": avatarUrl.trim()}),
    );
    return _parseUserResponse(
      resp,
      fallbackMessage: "Profil fotoğrafı güncellenemedi.",
    );
  }

  Future<Map<String, dynamic>> removeAvatar() async {
    final uri = Uri.parse("$_baseUrl/auth/me/avatar");
    final resp = await _client.delete(uri, headers: _authorizedJsonHeaders());
    return _parseUserResponse(
      resp,
      fallbackMessage: "Profil fotoğrafı kaldırılamadı.",
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/me/password");
    final resp = await _client.post(
      uri,
      headers: _authorizedJsonHeaders(),
      body: jsonEncode({
        "currentPassword": currentPassword,
        "newPassword": newPassword,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final message = _responseMessage(resp);
      throw Exception(
        message.isNotEmpty ? message : "Şifre güncellenemedi.",
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception("Şifre güncellenemedi.");
  }

  Future<Map<String, dynamic>> getNewspaperViewInfo({
    required DateTime date,
    bool preferLocal = false,
  }) async {
    final uri = Uri.parse("$_baseUrl/newspaper/view-url");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final normalized = DateTime(date.year, date.month, date.day);
    final dateOnly =
        "${normalized.year.toString().padLeft(4, "0")}-"
        "${normalized.month.toString().padLeft(2, "0")}-"
        "${normalized.day.toString().padLeft(2, "0")}";
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        "date": dateOnly,
        if (preferLocal) "preferLocal": true,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_newspaperViewUrlError(resp));
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = data["url"]?.toString().trim() ?? "";
    if (data["ok"] != true || url.isEmpty) {
      throw Exception("E-gazete bağlantısı alınamadı.");
    }
    return {
      "url": url,
      "isPrivate": data["isPrivate"] == true,
      "source": data["source"]?.toString() ?? "",
      "date": data["date"]?.toString() ?? dateOnly,
    };
  }

  Future<String> getNewspaperViewUrl({required DateTime date}) async {
    final info = await getNewspaperViewInfo(date: date);
    return info["url"]?.toString() ?? "";
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

  String _registerError(http.Response resp) {
    final message = _responseMessage(resp);
    switch (resp.statusCode) {
      case 400:
        return message.isNotEmpty ? message : "Üyelik bilgileri geçersiz.";
      case 409:
        return message.isNotEmpty
            ? message
            : "Bu e-posta adresiyle kayıtlı bir hesap zaten var.";
      case 429:
        return "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.";
      default:
        return message.isNotEmpty ? message : "Üyelik işlemi tamamlanamadı.";
    }
  }

  String _requestEmailVerificationError(http.Response resp) {
    final message = _responseMessage(resp);
    switch (resp.statusCode) {
      case 404:
        return "Hesap aktivasyon servisi henüz aktif değil.";
      case 429:
        return "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.";
      default:
        return message.isNotEmpty ? message : "Aktivasyon maili gönderilemedi.";
    }
  }

  String _confirmEmailVerificationError(http.Response resp) {
    final message = _responseMessage(resp);
    switch (resp.statusCode) {
      case 400:
      case 401:
        return message.isNotEmpty
            ? message
            : "Aktivasyon bağlantısı geçersiz veya kullanılmış.";
      case 410:
        return message.isNotEmpty
            ? message
            : "Aktivasyon bağlantısının süresi dolmuş.";
      case 404:
        return "Hesap aktivasyon servisi henüz aktif değil.";
      case 429:
        return "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.";
      default:
        return message.isNotEmpty ? message : "Hesap aktifleştirilemedi.";
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
    final code = _responseCode(resp);
    switch (resp.statusCode) {
      case 400:
        return message.isNotEmpty
            ? message
            : "Geçerli bir gazete tarihi seçin.";
      case 401:
        return "Gazeteyi görüntülemek için yeniden giriş yapın.";
      case 403:
        return message.isNotEmpty
            ? message
            : "Aktif e-gazete aboneliğiniz bulunmuyor.";
      case 404:
        if (code == "LOCAL_NEWSPAPER_NOT_FOUND") {
          return "Seçilen tarih uygulama arşivinde bulunamadı.";
        }
        return message.isNotEmpty
            ? message
            : "Seçilen tarihe ait e-gazete bulunamadı.";
      case 503:
        return message.isNotEmpty
            ? message
            : "E-gazete servisi şu anda kullanılamıyor.";
      default:
        return message.isNotEmpty ? message : "E-gazete bağlantısı alınamadı.";
    }
  }

  String _responseCode(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return decoded["code"]?.toString().trim() ?? "";
      }
    } catch (_) {}
    return "";
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

  Map<String, String> _authorizedJsonHeaders() {
    final token = AuthTokenStore.token?.trim();
    if (token == null || token.isEmpty) {
      throw Exception("Yetkilendirme bulunamadı. Lütfen tekrar giriş yapın.");
    }
    return {
      "content-type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Map<String, dynamic> _parseUserResponse(
    http.Response resp, {
    required String fallbackMessage,
  }) {
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      final code = _responseCode(resp);
      if (code.isNotEmpty) {
        throw Exception(code);
      }
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final message = _responseMessage(resp);
      throw Exception(message.isNotEmpty ? message : fallbackMessage);
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data["ok"] != true || data["user"] is! Map) {
      throw Exception(
        data["message"]?.toString() ??
            data["error"]?.toString() ??
            fallbackMessage,
      );
    }
    return Map<String, dynamic>.from(data["user"] as Map);
  }
}
