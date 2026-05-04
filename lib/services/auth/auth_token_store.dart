import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Indicates which kind of token is currently stored. Persisted alongside the
/// token itself so a stale `_activateGuestSession()` call cannot silently
/// overwrite an authenticated session — guest writes refuse to clobber an
/// `auth` token at the storage layer, regardless of in-memory state.
enum AuthTokenKind { auth, guest }

class AuthTokenStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "auth_token";
  static const _expiresKey = "auth_expires_at";
  static const _kindKey = "auth_token_kind";

  static String? _token;
  static DateTime? _expiresAt;
  static AuthTokenKind? _kind;

  static String? get token => _token;
  static DateTime? get expiresAt => _expiresAt;
  static AuthTokenKind? get kind => _kind;
  static bool get isExpired =>
      _expiresAt != null && DateTime.now().isAfter(_expiresAt!);
  static bool get isAuthenticated =>
      _kind == AuthTokenKind.auth && _token != null && _token!.isNotEmpty;

  static Future<void> load() async {
    _token = await _storage.read(key: _tokenKey);
    final rawExp = await _storage.read(key: _expiresKey);
    _expiresAt = rawExp != null ? DateTime.tryParse(rawExp) : null;
    final rawKind = await _storage.read(key: _kindKey);
    _kind = switch (rawKind) {
      "auth" => AuthTokenKind.auth,
      "guest" => AuthTokenKind.guest,
      _ => null,
    };
  }

  /// Saves a token. Guest writes refuse to clobber an existing auth-kind
  /// token — returns false in that case. Auth writes always succeed.
  static Future<bool> save({
    required String token,
    required DateTime expiresAt,
    required AuthTokenKind kind,
  }) async {
    if (kind == AuthTokenKind.guest && _kind == AuthTokenKind.auth) {
      // A real user is already authenticated; refuse to downgrade to guest.
      return false;
    }
    _token = token;
    _expiresAt = expiresAt;
    _kind = kind;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiresKey, value: expiresAt.toIso8601String());
    await _storage.write(key: _kindKey, value: kind.name);
    return true;
  }

  static Future<void> clear() async {
    _token = null;
    _expiresAt = null;
    _kind = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
    await _storage.delete(key: _kindKey);
  }
}
