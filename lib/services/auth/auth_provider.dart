import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_user.dart';
import 'user_service.dart';
import '../notification_service.dart';
import '../mail_manager.dart';
import '../mail_manager.dart';

class AuthProvider with ChangeNotifier {
  final UserService _userService = UserService();

  AppUser? _user;
  bool _isLoggedIn = false;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  static const keyUserId = "session_user_id";
  static const keyExpireAt = "session_expire_at";

  static const sessionDuration = Duration(days: 1);

  String _generateRandomPassword() {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rand = Random.secure();
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    final storedId = prefs.getInt(keyUserId);
    final expireAt = prefs.getInt(keyExpireAt);

    if (storedId == null || expireAt == null) {
      return;
    }

    final expireDate = DateTime.fromMillisecondsSinceEpoch(expireAt);

    if (DateTime.now().isAfter(expireDate)) {
      await logout();
      return;
    }

    final existingUser = await _userService.getUserById(storedId);

    _user = existingUser;
    _isLoggedIn = true;

    notifyListeners();
  }

  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final expire = DateTime.now().add(sessionDuration);

    await prefs.setInt(keyUserId, userId);
    await prefs.setInt(keyExpireAt, expire.millisecondsSinceEpoch);
  }

  Future<SocialLoginResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: "921079372710-ma27ah75aficaj4187kd4bnsls6386rr.apps.googleusercontent.com",
      ).signIn();
      if (googleUser == null) {
        return SocialLoginResult(error: "İşlem iptal edildi");
      }

      final GoogleSignInAuthentication gAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      final email = googleUser.email;
      final name = googleUser.displayName ?? email.split("@").first;

      final existing = await _userService.getUserByEmail(email);
      if (existing != null) {
        _isLoggedIn = true;
        _user = existing;
        await _saveSession(existing.id);
        await NotificationService().registerDeviceToken(userId: existing.id, forceRefresh: true);
        try {
          await MailManager.instance.sendWelcomeEmail(
            to: existing.email,
            name: existing.name,
          );
        } catch (e) {
          // ignore: avoid_print
          print("🔴 [Mail] Welcome mail gönderilemedi: $e");
        }
      notifyListeners();
      return SocialLoginResult(user: existing);
      }

      return SocialLoginResult(draft: SocialDraft(email: email, name: name));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("popup_closed")) {
        return SocialLoginResult(error: "Google penceresi kapatıldı, tekrar deneyin.");
      }
      return SocialLoginResult(error: msg);
    }
  }

  Future<AppUser?> registerSocialUser({
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      final password = _generateRandomPassword();
      final newUser = await _userService.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
      );
      _isLoggedIn = true;
      _user = newUser;
      await _saveSession(newUser.id);
      await NotificationService().registerDeviceToken(userId: newUser.id, forceRefresh: true);
      try {
        await MailManager.instance.sendWelcomeEmail(
          to: newUser.email,
          name: newUser.name,
        );
      } catch (e) {
        // ignore: avoid_print
        print("🔴 [Mail] Welcome mail gönderilemedi: $e");
      }
      notifyListeners();
      return newUser;
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
      final result = await _userService.login(email: email, password: password);

      if (result == null) {
        _isLoggedIn = false;
        _user = null;
        _errorMessage = "E-posta veya şifre hatalı";
      } else {
        _isLoggedIn = true;
        _user = result;

        await _saveSession(result.id);
        await NotificationService().registerDeviceToken(userId: result.id, forceRefresh: true);

        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString("saved_email", email);
          await prefs.setString("saved_password", password);
        } else {
          await prefs.remove("saved_email");
          await prefs.remove("saved_password");
        }
      }
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      _errorMessage = e.toString().replaceFirst("Exception:", "").trim();
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
      final newUser = await _userService.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
      );

      _isLoggedIn = true;
      _user = newUser;
      await _saveSession(newUser.id);
      await NotificationService().registerDeviceToken(userId: newUser.id, forceRefresh: true);
      try {
        await MailManager.instance.sendWelcomeEmail(
          to: newUser.email,
          name: newUser.name,
        );
      } catch (e) {
        // ignore: avoid_print
        print("🔴 [Mail] Welcome mail gönderilemedi: $e");
      }

      notifyListeners();
      return newUser;
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserId);
    await prefs.remove(keyExpireAt);

    _user = null;
    _isLoggedIn = false;
    _errorMessage = null;

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

  Future<void> updateProfile({
    required String name,
    String? phone,
  }) async {
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
}

class SocialDraft {
  final String email;
  final String name;
  final String? phone;

  SocialDraft({
    required this.email,
    required this.name,
    this.phone,
  });
}

class SocialLoginResult {
  final AppUser? user;
  final SocialDraft? draft;
  final String? error;

  SocialLoginResult({this.user, this.draft, this.error});

  bool get requiresRegistration => draft != null && user == null;
}
