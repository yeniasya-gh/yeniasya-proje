import '../../services/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RegisterBottomSheet extends StatefulWidget {
  const RegisterBottomSheet({super.key});

  @override
  State<RegisterBottomSheet> createState() => _RegisterBottomSheetState();
}

class _RegisterBottomSheetState extends State<RegisterBottomSheet> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final passAgainCtrl = TextEditingController();

  bool isLoading = false;
  bool obscure1 = true;
  bool obscure2 = true;

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Kayıt Ol",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),

                // ---------------- Ad Soyad ----------------
                TextFormField(
                  controller: nameCtrl,
                  decoration: _input("Ad Soyad", Icons.person),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? "Ad soyad giriniz" : null,
                ),
                const SizedBox(height: 16),

                // ---------------- Telefon ----------------
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _input("Telefon", Icons.phone),
                  validator: (v) => v == null || v.trim().length < 10
                      ? "Geçerli bir telefon giriniz"
                      : null,
                ),
                const SizedBox(height: 16),

                // ---------------- Email ----------------
                TextFormField(
                  controller: emailCtrl,
                  decoration: _input("E-posta", Icons.email),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "E-posta giriniz";
                    if (!v.contains("@")) return "Geçerli bir email değil";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ---------------- Şifre ----------------
                TextFormField(
                  controller: passCtrl,
                  obscureText: obscure1,
                  decoration: _inputWithToggle("Şifre", Icons.lock, () {
                    setState(() => obscure1 = !obscure1);
                  }, obscure1),
                  validator: (v) => v != null && v.length >= 6
                      ? null
                      : "En az 6 karakter olmalı",
                ),
                const SizedBox(height: 16),

                // ---------------- Şifre Tekrar ----------------
                TextFormField(
                  controller: passAgainCtrl,
                  obscureText: obscure2,
                  decoration: _inputWithToggle("Şifre tekrar", Icons.lock, () {
                    setState(() => obscure2 = !obscure2);
                  }, obscure2),
                  validator: (v) =>
                      v == passCtrl.text ? null : "Şifreler eşleşmiyor",
                ),

                const SizedBox(height: 24),

                // ---------------- Button ----------------
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setState(() => isLoading = true);

                            final newUser = await auth.register(
                              name: nameCtrl.text,
                              phone: phoneCtrl.text,
                              email: emailCtrl.text,
                              password: passCtrl.text,
                            );

                            setState(() => isLoading = false);

                            if (newUser != null) {
                              Navigator.pop(context);

                              Fluttertoast.showToast(
                                msg: "Kayıt başarılı 🎉",
                                toastLength: Toast.LENGTH_LONG,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                fontSize: 14,
                              );
                            }
                          },
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text(
                            "Kayıt Ol",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  // ------------ INPUT DECORATIONS ----------------
  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  InputDecoration _inputWithToggle(
    String label,
    IconData icon,
    VoidCallback toggle,
    bool isObscured,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
        onPressed: toggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
