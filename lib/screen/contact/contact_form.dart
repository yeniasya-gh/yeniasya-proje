import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/order_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/error/error_manager.dart';

class ContactForm extends StatefulWidget {
  final bool popOnSuccess;
  final bool showCompanyInfo;

  const ContactForm({
    super.key,
    this.popOnSuccess = true,
    this.showCompanyInfo = false,
  });

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.user?.id;
    final email = auth.user?.email;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bize Ulaşın",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (widget.showCompanyInfo) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    "Yeni Asya AŞ.\n"
                    "Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul\n"
                    "E-posta: bilgiislem@yeniasya.com.tr\n"
                    "KEP: yeniasya@kep.gov.tr",
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: "Konu Başlığı",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Konu girin" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  labelText: "Mesajınız",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Mesaj girin" : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _loading = true);
                          try {
                            await ContactService().sendContact(
                              subject: _subjectCtrl.text.trim(),
                              message: _messageCtrl.text.trim(),
                              userId: userId,
                              email: email,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Mesajınız iletildi"),
                              ),
                            );
                            if (widget.popOnSuccess) Navigator.pop(context);
                          } catch (e) {
                            final parsed = ErrorManager.parseGraphQLError(
                              e.toString(),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(parsed)));
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Text("Gönder"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
