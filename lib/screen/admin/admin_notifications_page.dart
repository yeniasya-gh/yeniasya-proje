import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/loading_manager.dart';
import 'admin_loading_indicator.dart';
import 'admin_subscription_warning_notifications_page.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _recipientSearchCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final NotificationService _service = NotificationService();
  bool _sending = false;
  bool _loadingNotifications = false;
  List<Map<String, dynamic>> _recipients = [];
  bool _loadingRecipients = false;
  bool _sendToAll = false;
  final Set<int> _selectedRecipientIds = <int>{};
  List<Map<String, dynamic>> _notifications = [];
  _AdminNotificationFilter _filter = _AdminNotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
    _loadNotifications();
  }

  Future<void> _loadRecipients() async {
    setState(() => _loadingRecipients = true);
    try {
      final recipients = await _service.getTokens();
      if (!mounted) return;
      setState(() => _recipients = recipients);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _loadingRecipients = false);
    }
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
    _recipientSearchCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "");
  }

  String _recipientLabel(Map<String, dynamic> recipient) {
    final name = recipient["name"]?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final email = recipient["email"]?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return "Kullanıcı ${recipient["id"] ?? "-"}";
  }

  String _recipientSubtitle(Map<String, dynamic> recipient) {
    final email = recipient["email"]?.toString().trim();
    final updatedAt = recipient["updated_at"]?.toString().trim();
    final parts = <String>[];
    if (email != null && email.isNotEmpty) parts.add(email);
    if (updatedAt != null && updatedAt.isNotEmpty) parts.add(updatedAt);
    return parts.isEmpty ? "" : parts.join(" • ");
  }

  List<Map<String, dynamic>> get _filteredRecipients {
    final query = _recipientSearchCtrl.text.trim().toLowerCase();
    final items = _recipients
        .where((recipient) {
          if (_sendToAll) return false;
          if (query.isEmpty) return true;
          final id = recipient["id"]?.toString().toLowerCase() ?? "";
          final name = recipient["name"]?.toString().toLowerCase() ?? "";
          final email = recipient["email"]?.toString().toLowerCase() ?? "";
          return id.contains(query) ||
              name.contains(query) ||
              email.contains(query);
        })
        .toList(growable: false);
    items.sort((a, b) {
      final aSelected = _selectedRecipientIds.contains(_asInt(a["id"])) ? 1 : 0;
      final bSelected = _selectedRecipientIds.contains(_asInt(b["id"])) ? 1 : 0;
      if (aSelected != bSelected) return bSelected.compareTo(aSelected);
      return _recipientLabel(a).compareTo(_recipientLabel(b));
    });
    return items;
  }

  List<int> get _selectedRecipientList {
    final ids = _selectedRecipientIds.toList(growable: false)..sort();
    return ids;
  }

  void _toggleRecipient(Map<String, dynamic> recipient) {
    final id = _asInt(recipient["id"]);
    if (id == null) return;
    setState(() {
      if (_selectedRecipientIds.contains(id)) {
        _selectedRecipientIds.remove(id);
      } else {
        _sendToAll = false;
        _selectedRecipientIds.add(id);
      }
    });
  }

  void _removeRecipient(int id) {
    setState(() => _selectedRecipientIds.remove(id));
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_sendToAll && _selectedRecipientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "En az bir kullanıcı seçin veya herkese gönder seçeneğini açın.",
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final userIds = _sendToAll ? null : _selectedRecipientList;
      final result = await _service.sendNotification(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        userIds: userIds,
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
      await _loadRecipients();
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
              Text("Kullanıcı: ${_notificationUserLabel(notification)}"),
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _sendToAll,
                  title: const Text("Herkese gönder"),
                  subtitle: const Text(
                    "Açık olursa seçili kullanıcılar yok sayılır ve tüm kullanıcılara gider.",
                  ),
                  onChanged: (value) {
                    setState(() {
                      _sendToAll = value;
                      if (value) {
                        _selectedRecipientIds.clear();
                        _recipientSearchCtrl.clear();
                      }
                    });
                  },
                ),
                if (!_sendToAll) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _recipientSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: "Kullanıcı ara",
                      hintText: "İsim veya e-posta ile ara",
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
                  if (_selectedRecipientIds.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Seçili kullanıcılar (${_selectedRecipientIds.length})",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedRecipientIds
                          .map((id) {
                            final recipient = _recipients.firstWhere(
                              (item) => _asInt(item["id"]) == id,
                              orElse: () => const <String, dynamic>{},
                            );
                            if (recipient.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Chip(
                              label: Text(_recipientLabel(recipient)),
                              onDeleted: () => _removeRecipient(id),
                            );
                          })
                          .whereType<Widget>()
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _loadingRecipients
                      ? const AdminLoadingIndicator(padding: EdgeInsets.all(16))
                      : Container(
                          constraints: const BoxConstraints(maxHeight: 240),
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
                          child: _filteredRecipients.isEmpty
                              ? const Center(
                                  child: Text("Eşleşen kullanıcı bulunamadı."),
                                )
                              : ListView.separated(
                                  itemCount: _filteredRecipients.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, index) {
                                    final recipient =
                                        _filteredRecipients[index];
                                    final id = _asInt(recipient["id"]);
                                    final selected =
                                        id != null &&
                                        _selectedRecipientIds.contains(id);
                                    return ListTile(
                                      dense: true,
                                      onTap: () => _toggleRecipient(recipient),
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: selected
                                            ? Colors.red.shade100
                                            : Colors.grey.shade200,
                                        child: Icon(
                                          selected
                                              ? Icons.check
                                              : Icons.person_outline,
                                          size: 18,
                                          color: selected
                                              ? Colors.red
                                              : Colors.black54,
                                        ),
                                      ),
                                      title: Text(
                                        _recipientLabel(recipient),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        _recipientSubtitle(recipient),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        selected ? "Seçildi" : "Ekle",
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ] else ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: const Text(
                      "Mesaj tüm kullanıcılara gönderilecek.",
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
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
                        return Text(_sendToAll ? "Herkese Gönder" : "Gönder");
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminSubscriptionWarningNotificationsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.schedule_outlined),
                    label: const Text("Abonelik Uyarıları"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                                  "Kullanıcı: ${_notificationUserLabel(item)}",
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
          final user = item["user"];
          final userName = user is Map
              ? (user["name"] ?? "").toString().toLowerCase()
              : "";
          final userEmail = user is Map
              ? (user["email"] ?? "").toString().toLowerCase()
              : "";
          final searchMatch =
              query.isEmpty ||
              title.contains(query) ||
              body.contains(query) ||
              userName.contains(query) ||
              userEmail.contains(query);
          return searchMatch;
        })
        .toList(growable: false);
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
