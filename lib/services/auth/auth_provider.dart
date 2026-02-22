import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../models/app_user.dart';
import 'auth_api_service.dart';
import 'auth_token_store.dart';
import 'user_service.dart';
import '../notification_service.dart';
import '../mail_manager.dart';

class AuthProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final AuthApiService _authApi = AuthApiService();

  AppUser? _user;
  bool _isLoggedIn = false;
  String? _errorMessage;
  Timer? _expiryTimer;

  VoidCallback? onLogout;

  AppUser? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  static const keyUserJson = "session_user_json";

  String _generateRandomPassword() {
    const chars =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rand = Random.secure();
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => charset[rand.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String? _normalizedValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _tokenFromPayload(Map<String, dynamic> payload) {
    final direct =
        _normalizedValue(payload["token"]?.toString()) ??
        _normalizedValue(payload["jwt"]?.toString());
    if (direct != null) return direct;

    final nested = payload["data"];
    if (nested is! Map) return null;
    final nestedMap = Map<String, dynamic>.from(nested);
    return _normalizedValue(nestedMap["token"]?.toString()) ??
        _normalizedValue(nestedMap["jwt"]?.toString());
  }

  DateTime _expiresAtFromPayload(Map<String, dynamic> payload) {
    final direct =
        _normalizedValue(payload["expiresAt"]?.toString()) ??
        _normalizedValue(payload["expires_at"]?.toString());
    if (direct != null) {
      final parsed = DateTime.tryParse(direct);
      if (parsed != null) return parsed;
    }

    final nested = payload["data"];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      final raw =
          _normalizedValue(nestedMap["expiresAt"]?.toString()) ??
          _normalizedValue(nestedMap["expires_at"]?.toString());
      if (raw != null) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }

    return DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _activateGuestSession({
    bool clearSavedUser = true,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (clearSavedUser) {
      await prefs.remove(keyUserJson);
    }

    final data = await _authApi.guestToken();
    final token = _tokenFromPayload(data);
    if (token == null || token.isEmpty) {
      throw Exception("Guest token alınamadı.");
    }
    final expiresAt = _expiresAtFromPayload(data);

    await AuthTokenStore.save(token: token, expiresAt: expiresAt);

    _user = null;
    _isLoggedIn = false;
    _errorMessage = null;
    _scheduleExpiry(expiresAt);
    if (notify) notifyListeners();
  }

  Future<void> _handleTokenExpiry() async {
    if (_isLoggedIn) {
      await logout();
      return;
    }
    try {
      await _activateGuestSession(clearSavedUser: false);
    } catch (e) {
      debugPrint("🔴 [Auth] guest token refresh failed: $e");
      await AuthTokenStore.clear();
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await AuthTokenStore.load();
      final token = AuthTokenStore.token?.trim();
      final expiresAt = AuthTokenStore.expiresAt;
      final hasValidToken =
          token != null &&
          token.isNotEmpty &&
          expiresAt != null &&
          !AuthTokenStore.isExpired;

      if (!hasValidToken) {
        await _activateGuestSession();
        return;
      }

      final rawUser = prefs.getString(keyUserJson);
      if (rawUser == null || rawUser.isEmpty) {
        await _activateGuestSession(clearSavedUser: false);
        return;
      }

      final decoded = jsonDecode(rawUser);
      if (decoded is! Map) {
        throw const FormatException("Session user payload must be a map.");
      }

      final userMap = Map<String, dynamic>.from(decoded);
      _user = AppUser.fromJson(userMap);
      _isLoggedIn = true;
      _errorMessage = null;

      _scheduleExpiry(expiresAt);
      notifyListeners();
    } catch (e) {
      // If stored auth data is stale/corrupted, clear it instead of crashing on launch.
      debugPrint("🔴 [Auth] loadSession failed, switching to guest: $e");
      try {
        await _activateGuestSession();
      } catch (guestError) {
        debugPrint("🔴 [Auth] guest session bootstrap failed: $guestError");
        _expiryTimer?.cancel();
        _expiryTimer = null;
        await AuthTokenStore.clear();
        _user = null;
        _isLoggedIn = false;
        _errorMessage = null;
        notifyListeners();
      }
    }
  }

  Future<void> _saveSession({
    required AppUser user,
    required DateTime expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserJson, jsonEncode(user.toJson()));
  }

  void _scheduleExpiry(DateTime expiresAt) {
    _expiryTimer?.cancel();
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) {
      unawaited(_handleTokenExpiry());
      return;
    }
    _expiryTimer = Timer(diff, () {
      unawaited(_handleTokenExpiry());
    });
  }

  Future<SocialLoginResult> signInWithGoogle() async {
    try {
      const webClientId = String.fromEnvironment(
        "GOOGLE_WEB_CLIENT_ID",
        defaultValue: "",
      );
      const iosClientId = String.fromEnvironment(
        "GOOGLE_IOS_CLIENT_ID",
        defaultValue:
            "921079372710-8npk6tcfr5b4e4jvsr69ckik4kma309d.apps.googleusercontent.com",
      );

      final isApplePlatform =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);
      final clientId = kIsWeb
          ? (webClientId.isEmpty ? null : webClientId)
          : (isApplePlatform && iosClientId.isNotEmpty ? iosClientId : null);
      final serverClientId = !kIsWeb && webClientId.isNotEmpty
          ? webClientId
          : null;

      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: clientId,
        serverClientId: serverClientId,
      ).signIn();
      if (googleUser == null) {
        return SocialLoginResult(error: "İşlem iptal edildi");
      }

      final GoogleSignInAuthentication gAuth = await googleUser.authentication;
      final accessToken = gAuth.accessToken;
      final idToken = gAuth.idToken;
      if ((accessToken == null || accessToken.isEmpty) &&
          (idToken == null || idToken.isEmpty)) {
        return SocialLoginResult(
          error:
              "Google kimlik doğrulaması tamamlanamadı. Lütfen tekrar deneyin.",
        );
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken?.isEmpty == true ? null : accessToken,
        idToken: idToken?.isEmpty == true ? null : idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      final email = googleUser.email;
      final name = googleUser.displayName ?? email.split("@").first;

      AppUser? existing;
      try {
        existing = await _userService.getUserByEmail(email);
      } catch (_) {
        return SocialLoginResult(
          error: "Google giriş için JWT endpointi gerekli.",
        );
      }
      if (existing != null) {
        _isLoggedIn = true;
        _user = existing;
        // Google giriş için JWT endpointi eklenmeli.
        await NotificationService().registerDeviceToken(
          userId: existing.id,
          forceRefresh: true,
        );
        notifyListeners();
        return SocialLoginResult(user: existing);
      }

      return SocialLoginResult(
        draft: SocialDraft(email: email, name: name),
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("popup_closed")) {
        return SocialLoginResult(
          error: "Google penceresi kapatıldı, tekrar deneyin.",
        );
      }
      final lower = msg.toLowerCase();
      if (lower.contains("sign_in_canceled") ||
          lower.contains("12501") ||
          lower.contains("canceled")) {
        return SocialLoginResult(error: "Google giriş işlemi iptal edildi.");
      }
      if (lower.contains("network_error")) {
        return SocialLoginResult(
          error:
              "Ağ bağlantısı hatası. İnternetinizi kontrol edip tekrar deneyin.",
        );
      }
      if (lower.contains("apiexception: 10") ||
          lower.contains("developer_error") ||
          lower.contains("sign_in_failed")) {
        return SocialLoginResult(
          error:
              "Google giriş yapılandırması geçersiz. Uygulama SHA-1 / OAuth ayarlarını kontrol edin.",
        );
      }
      return SocialLoginResult(error: msg);
    }
  }

  Future<SocialLoginResult> signInWithApple() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        return SocialLoginResult(error: "Apple ile giriş kullanılamıyor.");
      }
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = _normalizedValue(credential.identityToken);
      if (idToken == null) {
        return SocialLoginResult(error: "Apple token alınamadı.");
      }

      final oauth = AppleAuthProvider.credentialWithIDToken(
        idToken,
        rawNonce,
        AppleFullPersonName(
          givenName: _normalizedValue(credential.givenName),
          familyName: _normalizedValue(credential.familyName),
        ),
      );
      final result = await FirebaseAuth.instance.signInWithCredential(oauth);
      final email = credential.email ?? result.user?.email ?? result.user?.uid;
      if (email == null || email.isEmpty) {
        return SocialLoginResult(error: "Apple e-posta bilgisi alınamadı.");
      }
      final name = credential.givenName?.trim().isNotEmpty == true
          ? "${credential.givenName ?? ""} ${credential.familyName ?? ""}"
                .trim()
          : (result.user?.displayName ?? email.split("@").first);

      AppUser? existing;
      try {
        existing = await _userService.getUserByEmail(email);
      } catch (_) {
        return SocialLoginResult(
          error: "Apple giriş için JWT endpointi gerekli.",
        );
      }
      if (existing != null) {
        _isLoggedIn = true;
        _user = existing;
        await NotificationService().registerDeviceToken(
          userId: existing.id,
          forceRefresh: true,
        );
        notifyListeners();
        return SocialLoginResult(user: existing);
      }

      return SocialLoginResult(
        draft: SocialDraft(email: email, name: name),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialLoginResult(error: "Apple giriş işlemi iptal edildi.");
      }
      return SocialLoginResult(error: _mapAppleSignInError(e));
    } on FirebaseAuthException catch (e) {
      return SocialLoginResult(error: _mapAppleSignInError(e));
    } catch (e) {
      return SocialLoginResult(error: _mapAppleSignInError(e));
    }
  }

  String _mapAppleSignInError(Object error) {
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      final msg = (error.message ?? "").toLowerCase();
      final raw = error.toString().toLowerCase();

      if (code == "invalid-credential" ||
          code == "invalid-oauth-response" ||
          msg.contains("invalid oauth response from apple.com") ||
          raw.contains("invalid oauth response from apple.com")) {
        return "Apple kimlik doğrulaması geçersiz döndü. Firebase Apple Sign-In ayarlarında Team ID, Key ID, Service ID ve Private Key bilgilerini kontrol edin.";
      }
      if (code == "operation-not-allowed") {
        return "Firebase üzerinde Apple ile giriş etkin değil.";
      }
      if (code == "missing-or-invalid-nonce") {
        return "Apple nonce doğrulaması başarısız oldu. Uygulamayı kapatıp tekrar deneyin.";
      }
      if (code == "network-request-failed") {
        return "Ağ bağlantısı hatası. İnternetinizi kontrol edip tekrar deneyin.";
      }
      if (code == "account-exists-with-different-credential") {
        return "Bu e-posta başka bir giriş yöntemiyle kayıtlı. O yöntemle giriş yapıp Apple hesabını bağlayın.";
      }
      return error.message ?? error.code;
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains("authorizationerrorcode.canceled") ||
        lower.contains("sign_in_canceled")) {
      return "Apple giriş işlemi iptal edildi.";
    }
    return raw;
  }

  Future<AppUser?> registerSocialUser({
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      final password = _generateRandomPassword();
      final data = await _authApi.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      final user = AppUser.fromAuthJson(data["user"] as Map<String, dynamic>);
      final token = data["token"]?.toString();
      final rawExp = data["expiresAt"]?.toString();
      final expiresAt = rawExp != null && rawExp.isNotEmpty
          ? DateTime.parse(rawExp)
          : DateTime.now().add(const Duration(days: 1));
      if (token == null || token.isEmpty) {
        throw Exception("Token alınamadı.");
      }
      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
      _isLoggedIn = true;
      _user = user;
      await _saveSession(user: user, expiresAt: expiresAt);
      _scheduleExpiry(expiresAt);
      await NotificationService().registerDeviceToken(
        userId: user.id,
        forceRefresh: true,
      );
      try {
        await MailManager.instance.sendWelcomeEmail(
          to: user.email,
          name: user.name,
        );
      } catch (e) {
        // ignore: avoid_print
        print("🔴 [Mail] Welcome mail gönderilemedi: $e");
      }
      notifyListeners();
      return user;
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      _errorMessage = e.toString().replaceFirst("Exception:", "").trim();
      notifyListeners();
      return null;
    }
  }

  Future<AppUser?> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    _errorMessage = null;
    try {
      final data = await _authApi.login(email: email, password: password);
      final user = AppUser.fromAuthJson(data["user"] as Map<String, dynamic>);
      final token = data["token"]?.toString();
      final rawExp = data["expiresAt"]?.toString();
      final expiresAt = rawExp != null && rawExp.isNotEmpty
          ? DateTime.parse(rawExp)
          : DateTime.now().add(const Duration(days: 1));

      if (token == null || token.isEmpty) {
        throw Exception("Token alınamadı.");
      }

      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
      _isLoggedIn = true;
      _user = user;
      await _saveSession(user: user, expiresAt: expiresAt);
      _scheduleExpiry(expiresAt);
      await NotificationService().registerDeviceToken(
        userId: user.id,
        forceRefresh: true,
      );

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString("saved_email", email);
      } else {
        await prefs.remove("saved_email");
      }
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      final msg = e.toString();
      if (msg.contains("INVALID_CREDENTIALS")) {
        _errorMessage = "E-posta veya şifre hatalı.";
      } else {
        _errorMessage = "Bir hata oluştu. Lütfen tekrar deneyiniz.";
      }
    }

    notifyListeners();
    return _user;
  }

  Future<AppUser?> register({
    required String name,
    String? phone,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    try {
      final data = await _authApi.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      final user = AppUser.fromAuthJson(data["user"] as Map<String, dynamic>);
      final token = data["token"]?.toString();
      final rawExp = data["expiresAt"]?.toString();
      final expiresAt = rawExp != null && rawExp.isNotEmpty
          ? DateTime.parse(rawExp)
          : DateTime.now().add(const Duration(days: 1));

      if (token == null || token.isEmpty) {
        throw Exception("Token alınamadı.");
      }
      await AuthTokenStore.save(token: token, expiresAt: expiresAt);

      _isLoggedIn = true;
      _user = user;
      await _saveSession(user: user, expiresAt: expiresAt);
      _scheduleExpiry(expiresAt);
      await NotificationService().registerDeviceToken(
        userId: user.id,
        forceRefresh: true,
      );
      try {
        await MailManager.instance.sendWelcomeEmail(
          to: user.email,
          name: user.name,
        );
      } catch (e) {
        // ignore: avoid_print
        print("🔴 [Mail] Welcome mail gönderilemedi: $e");
      }

      notifyListeners();
      return user;
    } catch (e) {
      // ignore: avoid_print
      print("🔴 [Register] Hata: $e");
      _isLoggedIn = false;
      _user = null;
      _errorMessage = e.toString().replaceFirst("Exception:", "").trim();

      notifyListeners();
      return null;
    }
  }

  Future<void> logout({bool bootstrapGuest = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserJson);
    _expiryTimer?.cancel();
    _expiryTimer = null;
    await AuthTokenStore.clear();

    _user = null;
    _isLoggedIn = false;
    _errorMessage = null;

    if (bootstrapGuest) {
      try {
        await _activateGuestSession(clearSavedUser: false, notify: false);
      } catch (e) {
        debugPrint("🔴 [Auth] guest session bootstrap failed on logout: $e");
      }
    }
    onLogout?.call();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final current = _user;
    if (current == null) return;
    final updated = await _userService.getUserById(current.id);
    if (updated == null) return;
    _user = updated;
    notifyListeners();
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    final current = _user;
    if (current == null) return;
    final updated = await _userService.updateProfile(
      id: current.id,
      name: name,
      phone: phone,
    );
    if (updated != null) {
      _user = updated;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _user;
    if (current == null) return false;
    return _userService.changePassword(
      id: current.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<bool> deleteAccount() async {
    final current = _user;
    if (current == null) {
      _errorMessage = "Aktif kullanıcı bulunamadı.";
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    try {
      final deleted = await _userService.deleteAccount(id: current.id);
      if (!deleted) {
        _errorMessage = "Hesap silinemedi.";
        notifyListeners();
        return false;
      }
      await logout();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception:", "").trim();
      notifyListeners();
      return false;
    }
  }
}

class SocialDraft {
  final String email;
  final String name;
  final String? phone;

  SocialDraft({required this.email, required this.name, this.phone});
}

class SocialLoginResult {
  final AppUser? user;
  final SocialDraft? draft;
  final String? error;

  SocialLoginResult({this.user, this.draft, this.error});

  bool get requiresRegistration => draft != null && user == null;
}
