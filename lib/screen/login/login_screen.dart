import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_provider.dart';
import '../register/register_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    emailCtrl.addListener(_onTextChanged);
    passwordCtrl.addListener(_onTextChanged);
  }

  Future<void> _loadRememberedCredentials() async {
  final prefs = await SharedPreferences.getInstance();

  final savedEmail = prefs.getString("saved_email");
  final savedPassword = prefs.getString("saved_password");

  if (savedEmail != null && savedPassword != null) {
    setState(() {
      emailCtrl.text = savedEmail;
      passwordCtrl.text = savedPassword;
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

    return Scaffold(
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
                  "Dergi • Kitap • Gazete",
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
                                onPressed: () {},
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
                                      setState(() => isLoading = false);

                                      if (auth.isLoggedIn) {
                                        Navigator.pop(context);
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
                                    builder: (_) => const RegisterBottomSheet(),
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
    );
  }
}
