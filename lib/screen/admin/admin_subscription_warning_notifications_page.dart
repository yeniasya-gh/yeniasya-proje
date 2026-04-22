import 'package:flutter/material.dart';

import '../../services/error/error_manager.dart';
import '../../services/notification_service.dart';
import '../../utils/notification_date_formatter.dart';
import 'admin_loading_indicator.dart';
import '../notification/notification_detail_screen.dart';

class AdminSubscriptionWarningNotificationsPage extends StatefulWidget {
  const AdminSubscriptionWarningNotificationsPage({super.key});

  @override
  State<AdminSubscriptionWarningNotificationsPage> createState() =>
      _AdminSubscriptionWarningNotificationsPageState();
}

class _AdminSubscriptionWarningNotificationsPageState
    extends State<AdminSubscriptionWarningNotificationsPage> {
  final _service = NotificationService();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _deletingBusy = false;
  List<Map<String, dynamic>> _allItems = [];
  _AdminNotificationFilter _filter = _AdminNotificationFilter.all;

  static const _expiryKeywords = <String>[
    'abonelik',
    'bitiş',
    'bitis',
    'yenile',
    'yenileme',
    'yaklaşıyor',
    'yaklasiyor',
    'süresi',
    'sure',
    'hatırlatma',
    'hatirlatma',
    'expire',
    'expiration',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final notifications = await _service.getAdminNotifications(
        limit: 1000,
      );
      if (!mounted) return;
      setState(() => _allItems = notifications);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isSubscriptionWarningNotification(Map<String, dynamic> item) {
    final title = (item["title"] ?? "").toString().toLowerCase();
    final body = (item["body"] ?? "").toString().toLowerCase();
    final text = "$title $body";
    return _expiryKeywords.any(text.contains);
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
    if (_deletingBusy) return;
    setState(() => _deletingBusy = true);
    try {
      await _service.deleteNotification(id);
      if (!mounted) return;
      setState(() {
        _allItems.removeWhere((item) => item["id"] == id);
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _deletingBusy = false);
    }
  }

  String _notificationUserLabel(Map<String, dynamic> notification) {
    final user = notification["user"];
    if (user is Map) {
      final name = user["name"]?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final email = user["email"]?.toString().trim();
      if (email != null && email.isNotEmpty) return email;
    }
    final userId = notification["user_id"]?.toString().trim();
    return (userId != null && userId.isNotEmpty) ? "ID $userId" : "-";
  }

  Future<void> _openDetail(Map<String, dynamic> notification) async {
    final id = notification["id"] as int?;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notificationId: id),
      ),
    );
    if (mounted) await _load();
  }

  Widget _filterChip(String label, _AdminNotificationFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text("Abonelik Uyarıları"),
        actions: [
          IconButton(
            tooltip: "Yenile",
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      "Abonelik bitişine yaklaşan kullanıcılara gönderilen bildirimler.",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
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
              _loading
                  ? const AdminLoadingIndicator(padding: EdgeInsets.all(16))
                  : Expanded(
                      child: Container(
                        width: double.infinity,
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
                        child: items.isEmpty
                            ? const Center(
                                child: Text("Abonelik uyarısı bulunamadı."),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final item = items[index];
                                  final isRead = item["is_read"] == true;
                                  final date = formatNotificationDate(
                                    item["created_at"]?.toString(),
                                  );
                                  final title =
                                      item["title"]?.toString() ?? "-";
                                  final body =
                                      item["body"]?.toString() ?? "";
                                  final accent = isRead
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFE74C3C);
                                  return ListTile(
                                    onTap: () => _openDetail(item),
                                    leading: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent,
                                      ),
                                    ),
                                    title: Text(
                                      title,
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
                                        "Kullanıcı: ${_notificationUserLabel(item)}",
                                        body,
                                        date,
                                      ].join(" • "),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          tooltip: isRead
                                              ? "Okunmadı yap"
                                              : "Okundu yap",
                                          onPressed: () =>
                                              _toggleRead(item),
                                          icon: Icon(
                                            isRead
                                                ? Icons
                                                      .mark_email_unread_outlined
                                                : Icons
                                                      .mark_email_read_outlined,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: "Sil",
                                          onPressed: () =>
                                              _deleteNotification(item),
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
                    ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allItems.where((item) {
      final title = (item["title"] ?? "").toString().toLowerCase();
      final body = (item["body"] ?? "").toString().toLowerCase();
      final user = item["user"];
      final userName = user is Map
          ? (user["name"] ?? "").toString().toLowerCase()
          : "";
      final userEmail = user is Map
          ? (user["email"] ?? "").toString().toLowerCase()
          : "";
      final readMatch = switch (_filter) {
        _AdminNotificationFilter.all => true,
        _AdminNotificationFilter.read => item["is_read"] == true,
        _AdminNotificationFilter.unread => item["is_read"] != true,
      };
      final searchMatch = query.isEmpty ||
          title.contains(query) ||
          body.contains(query) ||
          userName.contains(query) ||
          userEmail.contains(query);
      return readMatch &&
          searchMatch &&
          _isSubscriptionWarningNotification(item);
    }).toList(growable: false);
    return filtered;
  }
}

enum _AdminNotificationFilter { all, unread, read }
