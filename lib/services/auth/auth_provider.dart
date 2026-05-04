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
import '../error/app_error_reporter.dart';
import '../notification_service.dart';
import '../secure_file_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthApiService? authApi, UserService? userService})
    : _authApi = authApi ?? AuthApiService(),
      _userService = userService ?? UserService();

  final UserService _userService;
  final AuthApiService _authApi;

  AppUser? _user;
  bool _isLoggedIn = false;
  String? _errorMessage;
  bool _needsEmailVerification = false;
  String? _verificationEmailHint;
  Timer? _expiryTimer;
  Timer? _sessionMonitorTimer;
  bool _sessionMonitorBusy = false;
  AuthLogoutReason? _lastLogoutReason;
  DateTime? _loginGraceUntil;
  int _sessionMutationId = 0;

  Future<void> Function(AuthLogoutReason reason)? onLogout;

  AppUser? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  bool get isOldManualNewspaperAccountError =>
      _errorMessage?.contains("OLD_MANUAL_NEWSPAPER_ACCOUNT") == true;
  String? get uiErrorMessage {
    final message = _errorMessage?.trim();
    if (message == null || message.isEmpty) return null;
    return _friendlyAuthErrorMessage(message);
  }

  bool get needsEmailVerification => _needsEmailVerification;
  String? get verificationEmailHint => _verificationEmailHint;
  AuthLogoutReason? get lastLogoutReason => _lastLogoutReason;
  bool get shouldForceLoginScreen =>
      _lastLogoutReason == AuthLogoutReason.sessionRevoked ||
      _lastLogoutReason == AuthLogoutReason.accountDeleted;

  static const keyUserJson = "session_user_json";
  static const keyLoginGraceUntil = "auth_login_grace_until";

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

  String _friendlyAuthErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (message.contains("OLD_MANUAL_NEWSPAPER_ACCOUNT")) {
      return "Sistemde aktif hesabınız bulunmaktadır.";
    }
    if (lower.contains("user_phone_already_exists") ||
        lower.contains("users_phone_key") ||
        lower.contains("users_phone_active_unique_idx") ||
        lower.contains(
          'duplicate key value violates unique constraint "users_phone_key"',
        ) ||
        lower.contains(
          'duplicate key value violates unique constraint "users_phone_active_unique_idx"',
        )) {
      return "Bu telefon numarası zaten kayıtlı.";
    }
    if (lower.contains("user_email_already_exists") ||
        lower.contains("users_email_key") ||
        lower.contains("users_email_active_unique_idx") ||
        lower.contains("users_email_lower_unique_idx") ||
        lower.contains(
          'duplicate key value violates unique constraint "users_email_key"',
        ) ||
        lower.contains(
          'duplicate key value violates unique constraint "users_email_active_unique_idx"',
        ) ||
        lower.contains(
          'duplicate key value violates unique constraint "users_email_lower_unique_idx"',
        )) {
      return "Bu e-posta adresi zaten kayıtlı.";
    }
    return message;
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

  bool _isSessionInvalidError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains("session_revoked") ||
        message.contains("invalid token") ||
        message.contains("missing token") ||
        message.contains("unauthorized");
  }

  bool _isWithinLoginGracePeriod() {
    final graceUntil = _loginGraceUntil;
    if (graceUntil == null) return false;
    return DateTime.now().isBefore(graceUntil);
  }

  Future<void> _markLoginGracePeriod({
    Duration duration = const Duration(minutes: 10),
  }) async {
    _loginGraceUntil = DateTime.now().add(duration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyLoginGraceUntil,
      _loginGraceUntil!.toIso8601String(),
    );
  }

  void _touchSessionMutation() {
    _sessionMutationId += 1;
  }

  Future<void> _clearLoginGracePeriod() async {
    _loginGraceUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLoginGraceUntil);
  }

  Future<void> _activateGuestSession({
    bool clearSavedUser = true,
    bool notify = true,
  }) async {
    _cancelSessionMonitor();
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
    _touchSessionMutation();
    unawaited(AppErrorReporter.instance.flushPending());

    _user = null;
    _isLoggedIn = false;
    _errorMessage = null;
    _needsEmailVerification = false;
    _verificationEmailHint = null;
    _lastLogoutReason = null;
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
    final sessionMutationIdAtStart = _sessionMutationId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await AuthTokenStore.load();
      final rawGraceUntil = prefs.getString(keyLoginGraceUntil);
      _loginGraceUntil =
          rawGraceUntil == null ? null : DateTime.tryParse(rawGraceUntil);
      final token = AuthTokenStore.token?.trim();
      final expiresAt = AuthTokenStore.expiresAt;
      final hasValidToken =
          token != null &&
          token.isNotEmpty &&
          expiresAt != null &&
          !AuthTokenStore.isExpired;

      if (!hasValidToken) {
        if (sessionMutationIdAtStart != _sessionMutationId) {
          return;
        }
        await _clearLoginGracePeriod();
        if (sessionMutationIdAtStart != _sessionMutationId) {
          return;
        }
        await _activateGuestSession();
        return;
      }

      final rawUser = prefs.getString(keyUserJson);
      if (rawUser == null || rawUser.isEmpty) {
        if (sessionMutationIdAtStart != _sessionMutationId) {
          return;
        }
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
      _needsEmailVerification = false;
      _verificationEmailHint = null;

      _scheduleExpiry(expiresAt);
      _scheduleSessionMonitor();
      notifyListeners();

      try {
        await _authApi.getMe();
        await _markLoginGracePeriod();
      } catch (e) {
        if (_isSessionInvalidError(e)) {
          if (_isWithinLoginGracePeriod()) {
            debugPrint(
              "🔶 [Auth] stored session invalid during login grace period: $e",
            );
            return;
          }
          if (sessionMutationIdAtStart != _sessionMutationId) {
            return;
          }
          debugPrint("🔴 [Auth] stored session revoked during loadSession: $e");
          await logout(
            bootstrapGuest: false,
            reason: AuthLogoutReason.sessionRevoked,
            message: "Oturumunuz sonlandırıldı. Lütfen tekrar giriş yapın.",
          );
          return;
        }
      }
    } catch (e) {
      // If stored auth data is stale/corrupted, clear it instead of crashing on launch.
      debugPrint("🔴 [Auth] loadSession failed, switching to guest: $e");
      try {
        if (sessionMutationIdAtStart != _sessionMutationId) {
          return;
        }
        await _clearLoginGracePeriod();
        if (sessionMutationIdAtStart != _sessionMutationId) {
          return;
        }
        await _activateGuestSession();
      } catch (guestError) {
        debugPrint("🔴 [Auth] guest session bootstrap failed: $guestError");
        _expiryTimer?.cancel();
        _expiryTimer = null;
        await AuthTokenStore.clear();
        _user = null;
        _isLoggedIn = false;
        _errorMessage = null;
        _needsEmailVerification = false;
        _verificationEmailHint = null;
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
    unawaited(AppErrorReporter.instance.flushPending());
  }

  void clearErrorMessage({bool notify = true}) {
    if (_errorMessage == null) return;
    _errorMessage = null;
    if (notify) notifyListeners();
  }

  Future<void> _clearUserLocalState(SharedPreferences prefs) async {
    final pdfStateKeys = prefs
        .getKeys()
        .where((key) => key.startsWith("pdf_state::"))
        .toList(growable: false);
    for (final key in pdfStateKeys) {
      await prefs.remove(key);
    }
    if (!kIsWeb) {
      await SecureFileService.instance.clearAllCachedPdfs();
    }
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

  void _cancelSessionMonitor() {
    _sessionMonitorTimer?.cancel();
    _sessionMonitorTimer = null;
    _sessionMonitorBusy = false;
  }

  void _scheduleSessionMonitor() {
    _cancelSessionMonitor();
    if (!_isLoggedIn || _user == null) return;

    final interval = kIsWeb
        ? const Duration(seconds: 30)
        : const Duration(seconds: 5);

    _sessionMonitorTimer = Timer.periodic(interval, (_) {
      if (!_isLoggedIn || _user == null || _sessionMonitorBusy) return;
      _sessionMonitorBusy = true;
      unawaited(() async {
        try {
          await refreshUser();
        } catch (e) {
          debugPrint("🔴 [Auth] session monitor refresh failed: $e");
        } finally {
          _sessionMonitorBusy = false;
        }
      }());
    });
  }

  Future<SocialLoginResult> _completeSocialLogin({
    required String provider,
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      final data = await _authApi.socialLogin(
        email: email,
        provider: provider,
        name: name,
        phone: phone,
      );
      final user = AppUser.fromAuthJson(data["user"] as Map<String, dynamic>);
      final token = _tokenFromPayload(data);
      if (token == null || token.isEmpty) {
        return SocialLoginResult(
          error:
              "${provider.toUpperCase()} girişi için token alınamadı. Lütfen tekrar deneyin.",
        );
      }
      final expiresAt = _expiresAtFromPayload(data);

      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
      _touchSessionMutation();
      _isLoggedIn = true;
      _user = user;
      await _saveSession(user: user, expiresAt: expiresAt);
      await _markLoginGracePeriod();
      _scheduleExpiry(expiresAt);
      _scheduleSessionMonitor();
      await NotificationService().registerDeviceToken(
        userId: user.id,
        forceRefresh: true,
      );
      _needsEmailVerification = false;
      _verificationEmailHint = null;
      _lastLogoutReason = null;
      _errorMessage = null;
      notifyListeners();
      return SocialLoginResult(user: user);
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (msg.contains("SOCIAL_USER_NOT_FOUND") ||
          msg.contains("USER_NOT_FOUND") ||
          lower.contains("kullanıcı bulunamadı")) {
        return SocialLoginResult(
          draft: SocialDraft(
            email: email,
            name: name,
            phone: phone,
            provider: provider,
          ),
        );
      }
      return SocialLoginResult(
        error:
            "${provider.toUpperCase()} hesabı ile giriş tamamlanamadı. Lütfen tekrar deneyin.",
      );
    }
  }

  Future<SocialLoginResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({"prompt": "select_account"});
        final result = await FirebaseAuth.instance.signInWithPopup(provider);
        final firebaseUser = result.user;
        final email = firebaseUser?.email?.trim();
        if (email == null || email.isEmpty) {
          return SocialLoginResult(
            error:
                "Google hesabından e-posta bilgisi alınamadı. Lütfen başka bir hesapla tekrar deneyin.",
          );
        }
        final displayName = firebaseUser?.displayName?.trim();
        final name = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : email.split("@").first;
        return _completeSocialLogin(
          provider: "google",
          email: email,
          name: name,
        );
      }

      const webClientId = String.fromEnvironment(
        "GOOGLE_WEB_CLIENT_ID",
        defaultValue:
            "921079372710-ma27ah75aficaj4187kd4bnsls6386rr.apps.googleusercontent.com",
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
      return _completeSocialLogin(provider: "google", email: email, name: name);
    } catch (e) {
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case "popup-closed-by-user":
          case "cancelled-popup-request":
            return SocialLoginResult(
              error: "Google penceresi kapatıldı, tekrar deneyin.",
            );
          case "popup-blocked":
            return SocialLoginResult(
              error:
                  "Tarayıcı Google giriş penceresini engelledi. Popup izni verip tekrar deneyin.",
            );
          case "unauthorized-domain":
            return SocialLoginResult(
              error:
                  "Bu domain Firebase Authentication içinde yetkilendirilmemiş. Authorized Domains ayarını kontrol edin.",
            );
          case "operation-not-allowed":
            return SocialLoginResult(
              error:
                  "Firebase üzerinde Google giriş sağlayıcısı aktif değil. Authentication -> Sign-in method ayarını kontrol edin.",
            );
        }
      }
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
      if (kIsWeb) {
        final provider = AppleAuthProvider();
        provider.addScope("email");
        provider.addScope("name");

        final result = await FirebaseAuth.instance.signInWithPopup(provider);
        final firebaseUser = result.user;
        final profile = result.additionalUserInfo?.profile ?? const {};

        final email =
            _normalizedValue(firebaseUser?.email) ??
            _normalizedValue(profile["email"]?.toString());
        if (email == null || email.isEmpty) {
          return SocialLoginResult(error: "Apple e-posta bilgisi alınamadı.");
        }

        final displayName = _normalizedValue(firebaseUser?.displayName);
        final givenName = _normalizedValue(profile["firstName"]?.toString());
        final familyName = _normalizedValue(profile["lastName"]?.toString());
        final fallbackName = [givenName, familyName]
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .join(" ")
            .trim();
        final name =
            displayName ??
            (fallbackName.isNotEmpty ? fallbackName : email.split("@").first);

        return _completeSocialLogin(
          provider: "apple",
          email: email,
          name: name,
        );
      }

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
      return _completeSocialLogin(provider: "apple", email: email, name: name);
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
      if (code == "popup-closed-by-user" || code == "cancelled-popup-request") {
        return "Apple giriş penceresi kapatıldı, tekrar deneyin.";
      }
      if (code == "popup-blocked") {
        return "Tarayıcı Apple giriş penceresini engelledi. Popup izni verip tekrar deneyin.";
      }
      if (code == "unauthorized-domain") {
        return "Bu domain Firebase Authentication içinde yetkilendirilmemiş. Authorized Domains ayarını kontrol edin.";
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
    required String provider,
    String? phone,
  }) async {
    try {
      _errorMessage = null;
      final data = await _authApi.socialRegister(
        name: name,
        email: email,
        provider: provider,
        phone: phone,
      );
      final user = AppUser.fromAuthJson(data["user"] as Map<String, dynamic>);
      final token = _tokenFromPayload(data);
      final expiresAt = _expiresAtFromPayload(data);
      if (token == null || token.isEmpty) {
        throw Exception("Token alınamadı.");
      }
      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
      _touchSessionMutation();
      _isLoggedIn = true;
      _user = user;
      await _saveSession(user: user, expiresAt: expiresAt);
      await _markLoginGracePeriod();
      _scheduleExpiry(expiresAt);
      _scheduleSessionMonitor();
      await NotificationService().registerDeviceToken(
        userId: user.id,
        forceRefresh: true,
      );
      _needsEmailVerification = false;
      _verificationEmailHint = null;
      _lastLogoutReason = null;
      _errorMessage = null;
      notifyListeners();
      return user;
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      _needsEmailVerification = false;
      _verificationEmailHint = null;
      _lastLogoutReason = null;
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
    _needsEmailVerification = false;
    _verificationEmailHint = null;
    try {
      final data = await _authApi.login(email: email, password: password);
      final user = AppUser.fromAuthJson(data["user"] as Map<String, dynamic>);
      final token = _tokenFromPayload(data);
      final expiresAt = _expiresAtFromPayload(data);

      if (token == null || token.isEmpty) {
        throw Exception("Token alınamadı.");
      }

      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
      _touchSessionMutation();
      _isLoggedIn = true;
      _user = user;
      await _saveSession(user: user, expiresAt: expiresAt);
      await _markLoginGracePeriod();
      _scheduleExpiry(expiresAt);
      await NotificationService().registerDeviceToken(
        userId: user.id,
        forceRefresh: true,
      );

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString("saved_email", email.trim().toLowerCase());
      } else {
        await prefs.remove("saved_email");
      }
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      final msg = e.toString();
      if (msg.contains("INVALID_CREDENTIALS")) {
        _errorMessage = "E-posta veya şifre hatalı.";
      } else if (msg.contains("EMAIL_NOT_VERIFIED")) {
        _needsEmailVerification = true;
        _verificationEmailHint = email.trim().toLowerCase();
        _errorMessage =
            "Hesabınızı onaylayın. E-posta adresinize gönderilen bağlantı ile hesabınızı aktifleştirin.";
      } else {
        _errorMessage = e.toString().replaceFirst("Exception:", "").trim();
      }
    }

    notifyListeners();
    return _user;
  }

  Future<bool> register({
    required String name,
    String? phone,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _needsEmailVerification = false;
    _verificationEmailHint = null;
    try {
      await _authApi.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _isLoggedIn = false;
      _user = null;
      _verificationEmailHint = email.trim().toLowerCase();
      _needsEmailVerification = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      _verificationEmailHint = email.trim().toLowerCase();
      _needsEmailVerification = false;
      _lastLogoutReason = null;
      _errorMessage = _friendlyAuthErrorMessage(
        e.toString().replaceFirst("Exception:", "").trim(),
      );

      notifyListeners();
      return false;
    }
  }

  Future<void> logout({
    bool bootstrapGuest = true,
    AuthLogoutReason reason = AuthLogoutReason.manual,
    String? message,
  }) async {
    _touchSessionMutation();
    NotificationService().clearRegisteredUser();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserJson);
    await _clearUserLocalState(prefs);
    await _clearLoginGracePeriod();
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _cancelSessionMonitor();
    await AuthTokenStore.clear();

    _user = null;
    _isLoggedIn = false;
    _errorMessage = message;
    _needsEmailVerification = false;
    _verificationEmailHint = null;
    _lastLogoutReason = reason;

    if (bootstrapGuest) {
      try {
        await _activateGuestSession(clearSavedUser: false, notify: false);
      } catch (e) {
        debugPrint("🔴 [Auth] guest session bootstrap failed on logout: $e");
      }
    }
    if (onLogout != null) {
      await onLogout!.call(reason);
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final current = _user;
    if (current == null) return;
    try {
      final updatedJson = await _authApi.getMe();
      final updatedUser = AppUser.fromAuthJson(updatedJson);
      if (_sameUser(current, updatedUser)) {
        await _markLoginGracePeriod();
        return;
      }
      await _setCurrentUser(updatedUser);
      await _markLoginGracePeriod();
    } catch (e) {
      if (_isSessionInvalidError(e)) {
        if (_isWithinLoginGracePeriod()) {
          debugPrint(
            "🔶 [Auth] refreshUser invalid during login grace period: $e",
          );
          return;
        }
        debugPrint("🔴 [Auth] refreshUser detected revoked session: $e");
        await logout(
          bootstrapGuest: false,
          reason: AuthLogoutReason.sessionRevoked,
          message: "Oturumunuz sonlandırıldı. Lütfen tekrar giriş yapın.",
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    final current = _user;
    if (current == null) return;
    final updatedJson = await _authApi.updateMe(name: name, phone: phone);
    await _setCurrentUser(AppUser.fromAuthJson(updatedJson));
  }

  Future<void> updateAvatar({required String avatarUrl}) async {
    final current = _user;
    if (current == null) return;
    final updatedJson = await _authApi.updateAvatar(avatarUrl: avatarUrl);
    await _setCurrentUser(AppUser.fromAuthJson(updatedJson));
  }

  Future<void> removeAvatar() async {
    final current = _user;
    if (current == null) return;
    final updatedJson = await _authApi.removeAvatar();
    await _setCurrentUser(AppUser.fromAuthJson(updatedJson));
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _user;
    if (current == null) return false;

    try {
      final data = await _authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final token = _tokenFromPayload(data);
      final expiresAt = _expiresAtFromPayload(data);
      final userPayload =
          data["user"] as Map<String, dynamic>? ??
          (data["data"] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data["data"] as Map)
              : null);
      final updatedUser = userPayload != null
          ? AppUser.fromAuthJson(userPayload)
          : current;

      if (token == null || token.isEmpty) {
        throw Exception("Token alınamadı.");
      }

      await AuthTokenStore.save(token: token, expiresAt: expiresAt);
      await _saveSession(user: updatedUser, expiresAt: expiresAt);
      await _setCurrentUser(updatedUser);
      _scheduleExpiry(expiresAt);
      _scheduleSessionMonitor();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("INVALID_CURRENT_PASSWORD") ||
          msg.contains("Mevcut şifre hatalı") ||
          msg.toLowerCase().contains("current password")) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> requestPasswordReset({required String email}) {
    return _authApi.requestPasswordReset(email: email);
  }

  Future<void> requestEmailVerification({required String email}) async {
    await _authApi.requestEmailVerification(email: email);
    _verificationEmailHint = email.trim().toLowerCase();
    notifyListeners();
  }

  Future<void> confirmEmailVerification({required String token}) async {
    await _authApi.confirmEmailVerification(token: token);
    _needsEmailVerification = false;
    _verificationEmailHint = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) {
    return _authApi.confirmPasswordReset(
      token: token,
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
      await logout(
        bootstrapGuest: false,
        reason: AuthLogoutReason.accountDeleted,
        message: "Hesabınız silindi. Tekrar giriş yapabilirsiniz.",
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception:", "").trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> _setCurrentUser(AppUser user) async {
    _user = user;
    _isLoggedIn = true;
    _errorMessage = null;
    _needsEmailVerification = false;
    _verificationEmailHint = null;
    _lastLogoutReason = null;
    final expiresAt =
        AuthTokenStore.expiresAt ?? DateTime.now().add(const Duration(days: 1));
    await _saveSession(user: user, expiresAt: expiresAt);
    _touchSessionMutation();
    await _markLoginGracePeriod();
    _scheduleSessionMonitor();
    notifyListeners();
  }

  bool _sameUser(AppUser left, AppUser right) {
    return left.id == right.id &&
        left.name == right.name &&
        left.email == right.email &&
        left.phone == right.phone &&
        left.roleId == right.roleId &&
        left.roleName == right.roleName &&
        left.payUniqe == right.payUniqe &&
        left.avatarUrl == right.avatarUrl;
  }
}

enum AuthLogoutReason { manual, sessionRevoked, accountDeleted }

class SocialDraft {
  final String email;
  final String name;
  final String? phone;
  final String provider;

  SocialDraft({
    required this.email,
    required this.name,
    this.phone,
    required this.provider,
  });
}

class SocialLoginResult {
  final AppUser? user;
  final SocialDraft? draft;
  final String? error;

  SocialLoginResult({this.user, this.draft, this.error});

  bool get requiresRegistration => draft != null && user == null;
}
