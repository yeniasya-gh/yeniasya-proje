import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_provider.dart';

class SocialRegisterBottomSheet extends StatefulWidget {
  final SocialDraft draft;

  const SocialRegisterBottomSheet({super.key, required this.draft});

  @override
  State<SocialRegisterBottomSheet> createState() => _SocialRegisterBottomSheetState();
}

class _SocialRegisterBottomSheetState extends State<SocialRegisterBottomSheet> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool loading = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    nameCtrl.text = widget.draft.name;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final auth = context.read<AuthProvider>();

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
                const Text("Kayıt Ol", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  widget.draft.email,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameCtrl,
                  decoration: _input("Ad Soyad", Icons.person),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Ad soyad giriniz" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _input("Telefon", Icons.phone),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => loading = true);
                            setState(() => errorText = null);
                            final user = await auth.registerSocialUser(
                              email: widget.draft.email,
                              name: nameCtrl.text,
                              phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                            );
                            setState(() => loading = false);
                            if (!mounted) return;
                            if (user != null) {
                              Navigator.pop(context, true);
                            } else {
                              setState(() => errorText = auth.errorMessage ?? "Kayıt başarısız");
                            }
                          },
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text("Kaydı Tamamla"),
                  ),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
}
