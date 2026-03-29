import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';
import '../../utils/notification_date_formatter.dart';
import 'notification_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final _service = NotificationService();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) throw Exception("Kullanıcı bulunamadı");
      final list = await _service.getUserNotificationsFiltered(
        userId,
        isRead: switch (_filter) {
          _NotificationFilter.all => null,
          _NotificationFilter.read => true,
          _NotificationFilter.unread => false,
        },
      );
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    if (mounted) setState(() => _loading = false);
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
        _items.removeWhere((item) => item["id"] == id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text("Bildirimler"),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Başlık veya içerikte ara",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip("Tümü", _NotificationFilter.all),
                        _filterChip("Okunmamış", _NotificationFilter.unread),
                        _filterChip("Okunmuş", _NotificationFilter.read),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _filteredItems.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 160),
                                Center(child: Text("Bildirim bulunamadı.")),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredItems.length,
                              itemBuilder: (_, i) =>
                                  _notificationCard(_filteredItems[i]),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _items
        .where((n) {
          final title = (n["title"] ?? "").toString().toLowerCase();
          final body = (n["body"] ?? "").toString().toLowerCase();
          final matchesSearch =
              query.isEmpty || title.contains(query) || body.contains(query);
          return matchesSearch;
        })
        .toList(growable: false);
  }

  Widget _notificationCard(Map<String, dynamic> n) {
    final title = n["title"] ?? "-";
    final body = n["body"] ?? "";
    final date = formatNotificationDate(n["created_at"]?.toString());
    final isRead = n["is_read"] == true;
    final accent = isRead ? const Color(0xFF16A34A) : const Color(0xFFE74C3C);
    final surface = isRead ? const Color(0xFFF8FAFC) : const Color(0xFFFFF7F5);

    return Dismissible(
      key: ValueKey("notification_${n["id"]}"),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check_circle_outline, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _service.markNotificationRead(id: n["id"] as int, isRead: true);
          if (mounted) {
            setState(() {
              n["is_read"] = true;
            });
          }
          return false;
        }
        return true;
      },
      onDismissed: (_) => _deleteNotification(n),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NotificationDetailScreen(notificationId: n["id"] as int),
              ),
            );
            if (mounted) await _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isRead ? 0.10 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRead
                        ? Icons.notifications_none_outlined
                        : Icons.notifications_active_outlined,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.25,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              margin: const EdgeInsets.only(left: 8, top: 1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "Yeni",
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            icon: Icons.schedule_outlined,
                            label: date,
                            background: const Color(0xFFFFFFFF),
                            foreground: const Color(0xFF4B5563),
                            border: const Color(0xFFE5E7EB),
                          ),
                          _metaChip(
                            icon: isRead
                                ? Icons.mark_email_read_outlined
                                : Icons.mark_email_unread_outlined,
                            label: isRead ? "Okundu" : "Okunmadı",
                            background: isRead
                                ? const Color(0xFFEFFAF3)
                                : const Color(0xFFFFF0EC),
                            foreground: accent,
                            border: accent.withValues(alpha: 0.18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _NotificationFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) {
        setState(() => _filter = filter);
        _load();
      },
    );
  }
}

enum _NotificationFilter { all, unread, read }
