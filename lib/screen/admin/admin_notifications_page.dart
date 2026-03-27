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
  final _userIdsCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final NotificationService _service = NotificationService();
  bool _sending = false;
  bool _loadingNotifications = false;
  List<Map<String, dynamic>> _tokens = [];
  bool _loadingTokens = false;
  List<Map<String, dynamic>> _notifications = [];
  _AdminNotificationFilter _filter = _AdminNotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTokens();
    _loadNotifications();
  }

  Future<void> _loadTokens() async {
    setState(() => _loadingTokens = true);
    try {
      final tokens = await _service.getTokens();
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

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final notifications = await _service.getAdminNotifications(
        search: _searchCtrl.text,
        isRead: switch (_filter) {
          _AdminNotificationFilter.all => null,
          _AdminNotificationFilter.read => true,
          _AdminNotificationFilter.unread => false,
        },
      );
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _loadingNotifications = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userIdsCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<int> _parseUserIds() {
    final raw = _userIdsCtrl.text.trim();
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r"[,\s]+"))
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final userIds = _parseUserIds();
      final result = await _service.sendNotification(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        userIds: userIds.isEmpty ? null : userIds,
        persist: true,
        dryRun: false,
      );
      final summary = Map<String, dynamic>.from(
        result["summary"] as Map? ?? const {},
      );
      final sent = summary["sent"] ?? 0;
      final failed = summary["failed"] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Bildirim gönderildi. Başarılı: $sent, Başarısız: $failed",
          ),
        ),
      );
      await _loadNotifications();
      await _loadTokens();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parsed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRead(Map<String, dynamic> notification) async {
    final id = notification["id"] as int?;
    if (id == null) return;
    final next = notification["is_read"] != true;
    try {
      await _service.markNotificationRead(id: id, isRead: next);
      if (!mounted) return;
      setState(() {
        notification["is_read"] = next;
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final id = notification["id"] as int?;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bildirim silinsin mi?"),
        content: const Text("Bu bildirim kalıcı olarak silinecek."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteNotification(id);
      if (!mounted) return;
      setState(() {
        _notifications.removeWhere((item) => item["id"] == id);
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
  }

  Future<void> _showNotificationDetail(
    Map<String, dynamic> notification,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notification["title"]?.toString() ?? "Bildirim"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("ID: ${notification["id"] ?? "-"}"),
              Text("Kullanıcı ID: ${notification["user_id"] ?? "-"}"),
              Text(
                "Durum: ${notification["is_read"] == true ? "Okunmuş" : "Okunmamış"}",
              ),
              const SizedBox(height: 8),
              Text(notification["body"]?.toString() ?? ""),
              const SizedBox(height: 8),
              Text(
                notification["created_at"]?.toString() ?? "",
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _toggleRead(notification);
            },
            child: Text(
              notification["is_read"] == true ? "Okunmadı Yap" : "Okundu Yap",
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteNotification(notification);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _filteredNotifications;
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
                  controller: _userIdsCtrl,
                  decoration: const InputDecoration(
                    labelText:
                        "Kullanıcı ID'leri (virgülle ayırın, boşsa herkese gönder)",
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendNotification,
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
          const Text(
            "Bildirim Yönetimi",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: "Başlık veya içerikte ara",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip("Tümü", _AdminNotificationFilter.all),
              _filterChip("Okunmamış", _AdminNotificationFilter.unread),
              _filterChip("Okunmuş", _AdminNotificationFilter.read),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Kayıtlı cihaz token'ları",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
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
                  height: 220,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Bildirim Listesi",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadingNotifications ? null : _loadNotifications,
              ),
            ],
          ),
          _loadingNotifications
              ? const AdminLoadingIndicator(padding: EdgeInsets.all(16))
              : Container(
                  height: 360,
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
                  child: notifications.isEmpty
                      ? const Center(child: Text("Bildirim bulunamadı."))
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = notifications[i];
                            final isRead = item["is_read"] == true;
                            return ListTile(
                              onTap: () => _showNotificationDetail(item),
                              leading: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isRead ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                item["title"]?.toString() ?? "-",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  "User: ${item["user_id"] ?? "-"}",
                                  item["body"]?.toString() ?? "",
                                ].join(" • "),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: isRead
                                        ? "Okunmadı yap"
                                        : "Okundu yap",
                                    onPressed: () => _toggleRead(item),
                                    icon: Icon(
                                      isRead
                                          ? Icons.mark_email_unread_outlined
                                          : Icons.mark_email_read_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Sil",
                                    onPressed: () => _deleteNotification(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _notifications
        .where((item) {
          final title = (item["title"] ?? "").toString().toLowerCase();
          final body = (item["body"] ?? "").toString().toLowerCase();
          final searchMatch =
              query.isEmpty || title.contains(query) || body.contains(query);
          return searchMatch;
        })
        .toList(growable: false);
  }

  Widget _filterChip(String label, _AdminNotificationFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) {
        setState(() => _filter = filter);
        _loadNotifications();
      },
    );
  }
}

enum _AdminNotificationFilter { all, unread, read }
