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

  Future<Map<String, dynamic>> guestToken({
    String? username,
    String? password,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/guest-token");
    final headers = {
      "content-type": "application/json",
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        "username": username ??
            const String.fromEnvironment(
              "GUEST_USERNAME",
              defaultValue: "yeniasyaguest",
            ),
        "password": password ??
            const String.fromEnvironment(
              "GUEST_PASSWORD",
              defaultValue: "yeniasya.guest.pass.2026",
            ),
      }),
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
}
