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
  String? _messagesFutureKey;
  Future<List<Map<String, dynamic>>>? _messagesFuture;

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
      _invalidateMessagesCache();
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

  void _invalidateMessagesCache() {
    _messagesFutureKey = null;
    _messagesFuture = null;
  }

  Future<List<Map<String, dynamic>>>? _resolveMessagesFuture(dynamic user) {
    if (user == null) return null;
    final key =
        "${user.id}|${(user.email ?? "").toString().trim().toLowerCase()}";
    if (_messagesFutureKey != key) {
      _messagesFutureKey = key;
      _messagesFuture = ContactService().getMyMessages();
    }
    return _messagesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;
    final messagesFuture = _resolveMessagesFuture(currentUser);

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
          if (currentUser != null) ...[
            const SizedBox(height: 24),
            _buildMyMessagesSection(messagesFuture),
          ],
        ],
      ),
    );
  }

  Widget _buildMyMessagesSection(
    Future<List<Map<String, dynamic>>>? messagesFuture,
  ) {
    if (messagesFuture == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Mesajlarım",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: "Yenile",
              onPressed: _loading
                  ? null
                  : () {
                      setState(_invalidateMessagesCache);
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: messagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "Mesajlar yüklenemedi.",
                  style: TextStyle(color: Colors.red.shade700),
                ),
              );
            }

            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  "Henüz gönderdiğiniz mesaj yok.",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }

            return Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _contactMessageCard(item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _contactMessageCard(Map<String, dynamic> item) {
    final reply = (item["reply_message"]?.toString() ?? "").trim();
    final replyAt = _formatDateTime(item["reply_at"]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _subjectOf(item),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(item["created_at"]),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _messageOf(item),
            style: TextStyle(color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (reply.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                "Henüz cevaplanmadı.",
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply_outlined,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        replyAt.isEmpty
                            ? "Cevaplandı"
                            : "Cevaplandı • $replyAt",
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reply,
                    style: TextStyle(color: Colors.green.shade900, height: 1.4),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _subjectOf(Map<String, dynamic> item) {
    final raw = item["subject"]?.toString().trim() ?? "";
    if (raw.isEmpty) return "Konu";
    final match = RegExp(r"^\[(.+?)\]\s*(.*)$").firstMatch(raw);
    if (match == null) return raw;
    final subject = match.group(2)?.trim() ?? "";
    return subject.isEmpty ? raw : subject;
  }

  String _messageOf(Map<String, dynamic> item) {
    final body = (item["message"]?.toString() ?? "").trim();
    if (body.isEmpty) return "(Mesaj içeriği boş)";
    return body
        .replaceFirst(RegExp(r"^Konu Türü:\s*.+?(?:\r?\n){1,2}"), "")
        .trim();
  }

  String _formatDateTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? "")?.toLocal();
    if (parsed == null) return "";
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(parsed.day)}.${two(parsed.month)}.${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}";
  }
}
