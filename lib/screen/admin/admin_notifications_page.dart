import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';
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
  Timer? _searchDebounce;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
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

  Future<void> _loadNotifications({int? page}) async {
    setState(() => _loadingNotifications = true);
    try {
      final requestedPage = page ?? _currentPage;
      final result = await _service.listAdminNotificationsPage(
        keyword: _searchCtrl.text,
        isRead: switch (_filter) {
          _AdminNotificationFilter.all => null,
          _AdminNotificationFilter.read => true,
          _AdminNotificationFilter.unread => false,
        },
        page: requestedPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final totalPages = _totalPagesFor(result.totalCount, _pageSize);
      final safePage = totalPages == 0 ? 1 : requestedPage.clamp(1, totalPages);
      if (safePage != requestedPage) {
        setState(() => _currentPage = safePage);
        await _loadNotifications(page: safePage);
        return;
      }
      setState(() {
        _notifications = result.items;
        _totalCount = result.totalCount;
        _currentPage = safePage;
      });
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
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_handleSearchChanged);
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

  List<int> get _selectedRecipientList {
    final ids = _selectedRecipientIds.toList(growable: false)..sort();
    return ids;
  }

  void _toggleRecipient(
    Map<String, dynamic> recipient,
    StateSetter dialogSetState,
  ) {
    final id = _asInt(recipient["id"]);
    if (id == null) return;
    dialogSetState(() {
      if (_selectedRecipientIds.contains(id)) {
        _selectedRecipientIds.remove(id);
      } else {
        _sendToAll = false;
        _selectedRecipientIds.add(id);
      }
    });
  }

  void _removeRecipient(int id, StateSetter dialogSetState) {
    dialogSetState(() => _selectedRecipientIds.remove(id));
  }

  void _resetComposeState() {
    _titleCtrl.clear();
    _bodyCtrl.clear();
    _recipientSearchCtrl.clear();
    _sendToAll = false;
    _selectedRecipientIds.clear();
  }

  Future<void> _openComposeDialog() async {
    if (_loadingRecipients && _recipients.isEmpty) {
      await _loadRecipients();
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_loadingRecipients,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            final dialogHeight = MediaQuery.of(dialogContext).size.height * 0.9;
            final filteredRecipients = _filteredRecipientsForDialog();
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 920, maxHeight: dialogHeight),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Bildirim Gönder",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Kapat",
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _loadingRecipients && _recipients.isEmpty
                            ? const AdminLoadingIndicator(
                                padding: EdgeInsets.all(16),
                              )
                            : SingleChildScrollView(
                                child: _buildComposeForm(
                                  dialogContext: dialogContext,
                                  dialogSetState: dialogSetState,
                                  filteredRecipients: filteredRecipients,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(_resetComposeState);
    } else {
      _resetComposeState();
    }
  }

  Future<void> _sendNotification(
    BuildContext dialogContext,
    StateSetter dialogSetState,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final dialogNavigator = Navigator.of(dialogContext);
    if (!_sendToAll && _selectedRecipientIds.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "En az bir kullanıcı seçin veya herkese gönder seçeneğini açın.",
          ),
        ),
      );
      return;
    }
    dialogSetState(() => _sending = true);
    var closed = false;
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Bildirim gönderildi. Başarılı: $sent, Başarısız: $failed",
          ),
        ),
      );
      closed = true;
      if (dialogNavigator.canPop()) {
        dialogNavigator.pop();
      }
      await _loadNotifications(page: 1);
      await _loadRecipients();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(parsed)));
    } finally {
      if (!closed && mounted) {
        dialogSetState(() => _sending = false);
      }
    }
  }

  Future<void> _toggleRead(Map<String, dynamic> notification) async {
    final id = _notificationId(notification);
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

  void _handleSearchChanged() {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadNotifications(page: 1);
    });
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final id = _notificationId(notification);
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

  int _totalPagesFor(int totalCount, int pageSize) {
    if (totalCount <= 0) return 0;
    final safePageSize = pageSize < 1 ? 1 : pageSize;
    return ((totalCount + safePageSize - 1) ~/ safePageSize);
  }

  void _goToPage(int page) {
    final safeTotalPages = _totalPagesFor(_totalCount, _pageSize);
    final safePage = page.clamp(1, safeTotalPages == 0 ? 1 : safeTotalPages);
    if (safePage == _currentPage) return;
    setState(() => _currentPage = safePage);
    _loadNotifications(page: safePage);
  }

  void _setPageSize(int value) {
    if (_pageSize == value) return;
    setState(() {
      _pageSize = value;
      _currentPage = 1;
    });
    _loadNotifications(page: 1);
  }

  void _setFilter(_AdminNotificationFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _currentPage = 1;
    });
    _loadNotifications(page: 1);
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

  int? _notificationId(Map<String, dynamic> notification) {
    final value = notification["id"];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }

  List<Map<String, dynamic>> _filteredRecipientsForDialog() {
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

  Widget _buildComposeForm({
    required BuildContext dialogContext,
    required StateSetter dialogSetState,
    required List<Map<String, dynamic>> filteredRecipients,
  }) {
    return Form(
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
              dialogSetState(() {
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
              onChanged: (_) => dialogSetState(() {}),
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
                        onDeleted: () => _removeRecipient(id, dialogSetState),
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
                    child: filteredRecipients.isEmpty
                        ? const Center(
                            child: Text("Eşleşen kullanıcı bulunamadı."),
                          )
                        : ListView.separated(
                            itemCount: filteredRecipients.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final recipient = filteredRecipients[index];
                              final id = _asInt(recipient["id"]);
                              final selected =
                                  id != null &&
                                  _selectedRecipientIds.contains(id);
                              return ListTile(
                                dense: true,
                                onTap: () =>
                                    _toggleRecipient(recipient, dialogSetState),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: selected
                                      ? Colors.red.shade100
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    selected ? Icons.check : Icons.person_outline,
                                    size: 18,
                                    color: selected ? Colors.red : Colors.black54,
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
                                    color: selected ? Colors.green : Colors.red,
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
          Row(
            children: [
              SizedBox(
                width: 220,
                height: 44,
                child: ElevatedButton(
                  onPressed: _sending
                      ? null
                      : () => _sendNotification(dialogContext, dialogSetState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_sendToAll ? "Herkese Gönder" : "Gönder"),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
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
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;
    final totalPages = _totalPagesFor(_totalCount, _pageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Bildirimler",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Toplam: $_totalCount",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openComposeDialog,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text("Bildirim Gönder"),
                ),
                OutlinedButton.icon(
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
                IconButton(
                  tooltip: "Yenile",
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadingNotifications
                      ? null
                      : () => _loadNotifications(page: _currentPage),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFiltersCard(),
        const SizedBox(height: 16),
        Expanded(
          child: _loadingNotifications
              ? const AdminLoadingIndicator()
              : _buildNotificationsSection(notifications, totalPages),
        ),
      ],
    );
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

  Widget _buildFiltersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final fieldWidth = wide
              ? ((constraints.maxWidth - 48) / 3).clamp(240.0, 420.0)
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) {},
                  decoration: InputDecoration(
                    labelText: "Başlık, içerik veya kullanıcı ara",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadNotifications(page: 1);
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<int>(
                  initialValue: _pageSize,
                  decoration: const InputDecoration(
                    labelText: "Sayfa boyutu",
                  ),
                  items: const [10, 20, 50]
                      .map(
                        (size) => DropdownMenuItem(
                          value: size,
                          child: Text("$size / sayfa"),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    _setPageSize(value);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip("Tümü", _AdminNotificationFilter.all),
                    _filterChip("Okunmamış", _AdminNotificationFilter.unread),
                    _filterChip("Okunmuş", _AdminNotificationFilter.read),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationsSection(
    List<Map<String, dynamic>> notifications,
    int totalPages,
  ) {
    return Column(
      children: [
        Expanded(
          child: Container(
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
                              tooltip: isRead ? "Okunmadı yap" : "Okundu yap",
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
        ),
        const SizedBox(height: 12),
        _paginationBar(totalPages),
      ],
    );
  }

  Widget _paginationBar(int totalPages) {
    final hasPrev = _currentPage > 1;
    final hasNext = _currentPage < totalPages;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          totalPages == 0
              ? "Sayfa 0 / 0"
              : "Sayfa $_currentPage / $totalPages",
          style: const TextStyle(color: Colors.black54),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: hasPrev ? () => _goToPage(_currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text("Önceki"),
            ),
            OutlinedButton.icon(
              onPressed: hasNext ? () => _goToPage(_currentPage + 1) : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text("Sonraki"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, _AdminNotificationFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => _setFilter(filter),
    );
  }
}

enum _AdminNotificationFilter { all, unread, read }
