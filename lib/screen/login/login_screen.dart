import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/access_provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/revenuecat_service.dart';
import '../register/register_bottom_sheet.dart';
import '../register/social_register_bottom_sheet.dart';
import '../home_responsive_screen.dart';
import 'password_reset_screen.dart';
import '../../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  static const String _googleSocialProvider = "google";
  static const String _appleSocialProvider = "apple";
  String? socialLoadingProvider;
  bool obscurePassword = true;
  bool rememberMe = false;

  bool get _isAnySocialLoading => socialLoadingProvider != null;
  bool get _isGoogleLoading => socialLoadingProvider == _googleSocialProvider;
  bool get _isAppleLoading => socialLoadingProvider == _appleSocialProvider;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    emailCtrl.addListener(_onTextChanged);
    passwordCtrl.addListener(_onTextChanged);
  }

  void _goHome() {
    if (!mounted) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeResponsiveScreen(initialUri: Uri.base),
      ),
      (route) => false,
    );
  }

  Future<void> _primePostLoginState() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      await Future.wait([
        context.read<AccessProvider>().load(user.id),
        context.read<RevenueCatService>().syncWithAuthUser(user),
      ]);
    } catch (e) {
      debugPrint("Post-login state prime failed: $e");
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isAnySocialLoading) return;
    final auth = context.read<AuthProvider>();
    setState(() => socialLoadingProvider = _googleSocialProvider);
    try {
      final result = await auth.signInWithGoogle();

      if (result.user != null) {
        await _primePostLoginState();
        _goHome();
        return;
      }

      if (result.draft != null && mounted) {
        final completed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => SocialRegisterBottomSheet(draft: result.draft!),
        );
        if (completed == true && mounted) {
          await _primePostLoginState();
          _goHome();
        }
        return;
      }

      if (result.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.error!)));
      }
    } finally {
      if (mounted) setState(() => socialLoadingProvider = null);
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isAnySocialLoading) return;
    final auth = context.read<AuthProvider>();
    setState(() => socialLoadingProvider = _appleSocialProvider);
    try {
      final result = await auth.signInWithApple();

      if (result.user != null) {
        await _primePostLoginState();
        _goHome();
        return;
      }

      if (result.draft != null && mounted) {
        final completed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => SocialRegisterBottomSheet(draft: result.draft!),
        );
        if (completed == true && mounted) {
          await _primePostLoginState();
          _goHome();
        }
        return;
      }

      if (result.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.error!)));
      }
    } finally {
      if (mounted) setState(() => socialLoadingProvider = null);
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final savedEmail = prefs.getString("saved_email");

    if (savedEmail != null) {
      setState(() {
        emailCtrl.text = savedEmail;
        rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  bool get isButtonEnabled {
    return emailCtrl.text.trim().isNotEmpty &&
        passwordCtrl.text.trim().isNotEmpty &&
        !isLoading;
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isWeb = MediaQuery.of(context).size.width > 900;

    return WillPopScope(
      onWillPop: () async {
        final nav = rootNavigatorKey.currentState;
        if (nav == null) return true;
        if (nav.canPop()) return true;
        nav.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeResponsiveScreen(initialUri: Uri.base),
          ),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Üye Girişi"),
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 0 : 16,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Image.asset(
                    "assets/images/logo.png",
                    height: isWeb ? 90 : 70,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "E-Dergiler • E-Kitaplar • E-Gazete",
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // LOGIN CARD
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 24),

                            // EMAIL
                            const Text(
                              "E-posta",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailCtrl,
                              decoration: InputDecoration(
                                hintText: "ornek@email.com",
                                prefixIcon: const Icon(Icons.mail_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF7F7F7),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.transparent,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDDDDDD),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // PASSWORD
                            const Text(
                              "Şifre",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordCtrl,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                hintText: "*******",
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() {
                                    obscurePassword = !obscurePassword;
                                  }),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F7F7),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.transparent,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDDDDDD),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // REMEMBER ME
                            Row(
                              children: [
                                Checkbox(
                                  value: rememberMe,
                                  onChanged: (v) =>
                                      setState(() => rememberMe = v ?? false),
                                ),
                                const Text(
                                  "Beni hatırla",
                                  style: TextStyle(fontSize: 13),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PasswordResetScreen(
                                              email: emailCtrl.text.trim(),
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Şifremi unuttum",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isButtonEnabled
                                      ? Colors.red
                                      : Colors.red.shade200,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: isButtonEnabled
                                    ? () async {
                                        setState(() => isLoading = true);
                                        await auth.login(
                                          emailCtrl.text.trim(),
                                          passwordCtrl.text.trim(),
                                          rememberMe: rememberMe,
                                        );
                                        if (auth.isLoggedIn) {
                                          await _primePostLoginState();
                                        }
                                        setState(() => isLoading = false);

                                        if (auth.isLoggedIn) {
                                          _goHome();
                                        }
                                      }
                                    : null,
                                child: isLoading
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        "Giriş Yap",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Opacity(
                              opacity: _isAnySocialLoading && !_isGoogleLoading
                                  ? 0.6
                                  : 1,
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  icon: _isGoogleLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          FontAwesomeIcons.google,
                                          color: Colors.red,
                                        ),
                                  label: const Text(
                                    "Google ile devam et",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _isAnySocialLoading
                                      ? null
                                      : _handleGoogleSignIn,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (kIsWeb || Platform.isIOS) ...[
                              Opacity(
                                opacity: _isAnySocialLoading && !_isAppleLoading
                                    ? 0.6
                                    : 1,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    icon: _isAppleLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            FontAwesomeIcons.apple,
                                            color: Colors.black87,
                                          ),
                                    label: const Text(
                                      "Apple ile devam et",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _isAnySocialLoading
                                        ? null
                                        : _handleAppleSignIn,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            if (auth.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  auth.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Hesabınız yok mu? "),
                                TextButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      useRootNavigator: true,
                                      backgroundColor: Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                      ),
                                      builder: (_) =>
                                          const RegisterBottomSheet(),
                                    );
                                  },
                                  child: const Text(
                                    "Kayıt ol",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
