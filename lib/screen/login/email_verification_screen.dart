import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? token;
  final String? email;

  const EmailVerificationScreen({super.key, this.token, this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _submitting = false;
  bool _requestCompleted = false;
  bool _verificationCompleted = false;
  bool _autoConfirmTriggered = false;
  String? _confirmError;

  String get _token => widget.token?.trim() ?? "";
  bool get _isConfirmMode => _token.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email?.trim() ?? "";
    if (_isConfirmMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoConfirmTriggered) return;
        _autoConfirmTriggered = true;
        _confirmVerification();
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestVerification() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().requestEmailVerification(
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

  Future<void> _confirmVerification() async {
    setState(() {
      _submitting = true;
      _confirmError = null;
    });
    try {
      await context.read<AuthProvider>().confirmEmailVerification(token: _token);
      if (!mounted) return;
      setState(() => _verificationCompleted = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirmError = _cleanError(e));
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
    final emailRegex = RegExp(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    if (!emailRegex.hasMatch(email)) return "Geçerli bir e-posta girin.";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          _isConfirmMode ? "Hesap Aktivasyonu" : "Aktivasyon Maili Gönder",
        ),
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
            child: _isConfirmMode
                ? _buildConfirmCard(context)
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
        title: "Aktivasyon maili gönderildi",
        message:
            "Bu e-posta adresi sistemde kayıtlıysa hesap aktivasyon bağlantısı gönderildi.",
        footer:
            "Gelen kutusu ve spam klasörünü kontrol edin. Hesabınızı onayladıktan sonra giriş yapabilirsiniz.",
      );
    }

    return _cardShell(
      child: Form(
        key: _requestFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Hesabınızı aktifleştirin",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              "Kayıtlı e-posta adresinizi girin. Size tek kullanımlık bir aktivasyon bağlantısı göndereceğiz.",
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
                onPressed: _submitting ? null : _requestVerification,
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
                    : const Text("Aktivasyon Maili Gönder"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmCard(BuildContext context) {
    if (_verificationCompleted) {
      return _statusCard(
        icon: Icons.verified_user_outlined,
        title: "Hesabınız aktifleştirildi",
        message:
            "E-posta adresiniz başarıyla doğrulandı. Artık hesabınızla giriş yapabilirsiniz.",
        footer:
            "Giriş ekranına dönüp e-posta adresiniz ve şifrenizle oturum açabilirsiniz.",
      );
    }

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Aktivasyon doğrulanıyor",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            widget.email?.trim().isNotEmpty == true
                ? "Bağlantı ${widget.email!.trim()} hesabı için oluşturuldu."
                : "Aktivasyon bağlantınız doğrulandıktan sonra hesabınız kullanıma açılacaktır.",
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                if (_submitting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.mail_lock_outlined, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _confirmError ??
                        (_submitting
                            ? "Hesabınız aktifleştiriliyor..."
                            : "Aktivasyon bağlantınızı onaylamaya hazırız."),
                    style: TextStyle(
                      color: _confirmError == null ? Colors.black87 : Colors.red,
                      height: 1.45,
                      fontWeight: _confirmError == null
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _confirmVerification,
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
                  : Text(_confirmError == null ? "Aktivasyonu Onayla" : "Tekrar Dene"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: child,
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String message,
    String? footer,
  }) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.55),
          ),
          if (footer != null) ...[
            const SizedBox(height: 14),
            Text(
              footer,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
