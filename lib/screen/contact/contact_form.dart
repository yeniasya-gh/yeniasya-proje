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
  static const List<String> _topicOptions = [
    "İstek, Tavsiye veya Şikayet",
    "Hata Bildirimi",
    "Üyelik, Abonelik ve Satın Alma İşlemleri",
  ];

  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;
  String? _selectedTopic;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitContact() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    final email = auth.user?.email;
    final selectedTopic = _selectedTopic?.trim() ?? "";
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final taggedSubject = selectedTopic.isEmpty
        ? subject
        : "[$selectedTopic] $subject";
    final taggedMessage = selectedTopic.isEmpty
        ? message
        : "Konu Türü: $selectedTopic\n\n$message";

    setState(() => _loading = true);
    try {
      await ContactService().sendContact(
        subject: taggedSubject,
        message: taggedMessage,
        userId: userId,
        email: email,
      );
      if (!mounted) return;

      if (widget.popOnSuccess) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text("Mesajınız iletildi, teşekkür ederiz.")),
      );
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(parsed)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            "Bize Ulaşın",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
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
              "İletişim:\n\n"
              "Yeni Asya Gazetecilik Matbaacılık ve Yayıncılık Sanayi ve Ticaret A.Ş.\n"
              "Adres: 15 Temmuz Mah.1508 Sk. No: 3 Posta Kodu: 34212 Güneşli / İSTANBUL\n"
              "Telefon: 0 (212) 655 88 59\n"
              "E-posta: app@yeniasya.com.tr",
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
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
                "Konu türünü seçerek ilettiğiniz mesajlar ilgili birime daha hızlı yönlendirilir.",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedTopic,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: "Konu Türü",
              border: OutlineInputBorder(),
            ),
            items: _topicOptions
                .map(
                  (topic) => DropdownMenuItem<String>(
                    value: topic,
                    child: Text(topic),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) => setState(() => _selectedTopic = value),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Konu türü seçin" : null,
          ),
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
              onPressed: _loading ? null : _submitContact,
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
    );
  }
}
