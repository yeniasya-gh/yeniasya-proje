import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "auth_token";
  static const _expiresKey = "auth_expires_at";

  static String? _token;
  static DateTime? _expiresAt;

  static String? get token => _token;
  static DateTime? get expiresAt => _expiresAt;
  static bool get isExpired =>
      _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  static Future<void> load() async {
    _token = await _storage.read(key: _tokenKey);
    final rawExp = await _storage.read(key: _expiresKey);
    _expiresAt = rawExp != null ? DateTime.tryParse(rawExp) : null;
  }

  static Future<void> save({
    required String token,
    required DateTime expiresAt,
  }) async {
    _token = token;
    _expiresAt = expiresAt;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiresKey, value: expiresAt.toIso8601String());
  }

  static Future<void> clear() async {
    _token = null;
    _expiresAt = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
  }
}
