import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/loading_manager.dart';
import 'admin_loading_indicator.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  bool _sending = false;
  List<Map<String, dynamic>> _tokens = [];
  bool _loadingTokens = false;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _loadingTokens = true);
    try {
      final tokens = await NotificationService().getTokens();
      setState(() => _tokens = tokens);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loadingTokens = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bildirim Gönder",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: "Başlık"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Başlık gerekli" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: "İçerik"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "İçerik gerekli" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _userIdCtrl,
                  decoration: const InputDecoration(
                    labelText: "Kullanıcı ID (boş: toplu gönder)",
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _sending
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _sending = true);
                            try {
                              final userId = int.tryParse(
                                _userIdCtrl.text.trim(),
                              );
                              final result = await NotificationService()
                                  .sendNotification(
                                    title: _titleCtrl.text.trim(),
                                    body: _bodyCtrl.text.trim(),
                                    userId: userId,
                                  );
                              final summary = Map<String, dynamic>.from(
                                result["summary"] as Map? ?? const {},
                              );
                              final sent = summary["sent"] ?? 0;
                              final failed = summary["failed"] ?? 0;
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Bildirim gönderildi. Başarılı: $sent, Başarısız: $failed",
                                  ),
                                ),
                              );
                            } catch (e) {
                              final parsed = ErrorManager.parseGraphQLError(
                                e.toString(),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(parsed)));
                            } finally {
                              if (mounted) setState(() => _sending = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: AnimatedBuilder(
                      animation: LoadingManager.instance,
                      builder: (_, __) {
                        if (_sending && !LoadingManager.instance.loading) {
                          return const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          );
                        }
                        return const Text("Gönder");
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Kayıtlı cihaz token'ları",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadTokens,
              ),
            ],
          ),
          _loadingTokens
              ? const AdminLoadingIndicator(padding: EdgeInsets.all(16))
              : Container(
                  height: 300,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    itemCount: _tokens.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text("User: ${_tokens[i]["user_id"] ?? "-"}"),
                      subtitle: Text(_tokens[i]["token"] ?? ""),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
