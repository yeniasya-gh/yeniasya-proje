import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth/auth_provider.dart';

class PasswordResetScreen extends StatefulWidget {
  final String? token;
  final String? email;

  const PasswordResetScreen({super.key, this.token, this.email});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _submitting = false;
  bool _requestCompleted = false;
  bool _resetCompleted = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String get _token => widget.token?.trim() ?? "";
  bool get _isResetMode => _token.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email?.trim() ?? "";
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().requestPasswordReset(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _requestCompleted = true);
    } catch (e) {
      if (!mounted) return;
      _showError(_cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().confirmPasswordReset(
        token: _token,
        newPassword: _newPasswordCtrl.text.trim(),
      );
      if (!mounted) return;
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      setState(() => _resetCompleted = true);
    } catch (e) {
      if (!mounted) return;
      _showError(_cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst("Exception:", "").trim();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? "";
    if (email.isEmpty) return "E-posta zorunlu.";
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(email)) return "Geçerli bir e-posta girin.";
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value?.trim() ?? "";
    if (password.isEmpty) return "Yeni şifre zorunlu.";
    if (password.length < 8) return "En az 8 karakter olmalı.";
    if (!RegExp(r"[A-Z]").hasMatch(password)) {
      return "En az 1 büyük harf içermeli.";
    }
    if (!RegExp(r"[a-z]").hasMatch(password)) {
      return "En az 1 küçük harf içermeli.";
    }
    if (!RegExp(r"[0-9]").hasMatch(password)) {
      return "En az 1 rakam içermeli.";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(_isResetMode ? "Yeni Şifre Belirle" : "Şifremi Unuttum"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _isResetMode
                ? _buildResetCard(context)
                : _buildRequestCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context) {
    if (_requestCompleted) {
      return _statusCard(
        icon: Icons.mark_email_read_outlined,
        title: "Bağlantı gönderildi",
        message:
            "Bu e-posta adresi sistemde kayıtlıysa şifre sıfırlama bağlantısı gönderildi. Güvenlik nedeniyle hesabın var olup olmadığını ayrıca göstermiyoruz.",
        footer:
            "Bağlantı tipik olarak 30 dakika geçerlidir. Gelen kutusu ve spam klasörünü kontrol edin.",
      );
    }

    return _cardShell(
      child: Form(
        key: _requestFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Şifre sıfırlama bağlantısı",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              "Kayıtlı e-posta adresinizi girin. Size tek kullanımlık bir sıfırlama bağlantısı göndereceğiz.",
              style: TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: "E-posta",
                hintText: "ornek@email.com",
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _requestReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Sıfırlama Maili Gönder"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetCard(BuildContext context) {
    if (_resetCompleted) {
      return _statusCard(
        icon: Icons.verified_user_outlined,
        title: "Şifre güncellendi",
        message:
            "Şifreniz başarıyla güncellendi. Aynı bağlantı tekrar kullanılamaz.",
        footer:
            "Giriş ekranına dönüp yeni şifrenizle oturum açabilirsiniz.",
      );
    }

    return _cardShell(
      child: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Yeni şifrenizi belirleyin",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              widget.email?.trim().isNotEmpty == true
                  ? "Bağlantı ${widget.email!.trim()} hesabı için oluşturuldu."
                  : "Bağlantı doğrulandıktan sonra yeni şifreniz kaydedilecektir.",
              style: const TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _newPasswordCtrl,
              obscureText: _obscureNewPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: "Yeni Şifre",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    );
                  },
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: "Yeni Şifre (Tekrar)",
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword =
                          !_obscureConfirmPassword,
                    );
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Şifre tekrarı zorunlu.";
                }
                if (value.trim() != _newPasswordCtrl.text.trim()) {
                  return "Şifreler eşleşmiyor.";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                "Şifreniz en az 8 karakter olmalı; büyük harf, küçük harf ve rakam içermelidir.",
                style: TextStyle(color: Colors.black54, height: 1.45),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _confirmReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Şifreyi Güncelle"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String message,
    String? footer,
  }) {
    final canPop = Navigator.of(context).canPop();
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 44, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: Colors.black87, height: 1.5),
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(
              footer,
              style: const TextStyle(color: Colors.black54, height: 1.45),
            ),
          ],
          if (canPop) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Geri Dön"),
            ),
          ],
        ],
      ),
    );
  }
}
