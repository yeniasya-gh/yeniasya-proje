import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_user.dart';
import 'user_service.dart';

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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserId);
    await prefs.remove(keyExpireAt);

    _user = null;
    _isLoggedIn = false;
    _errorMessage = null;

    notifyListeners();
  }
}
