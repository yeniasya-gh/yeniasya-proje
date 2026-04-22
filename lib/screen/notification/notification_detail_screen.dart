import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';
import '../../utils/notification_date_formatter.dart';

class NotificationDetailScreen extends StatefulWidget {
  final int notificationId;
  final Map<String, dynamic>? initialNotification;

  const NotificationDetailScreen({
    super.key,
    required this.notificationId,
    this.initialNotification,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _service = NotificationService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialNotification;
    _load();
  }

  String _fallbackTitle() {
    final title = widget.initialNotification?['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    return "Bildirim";
  }

  String _fallbackBody() {
    final body = widget.initialNotification?['body']?.toString().trim();
    if (body != null && body.isNotEmpty) return body;
    return "Bildirim içeriği bulunamadı.";
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await _service.getNotificationDetail(
        widget.notificationId,
      );
      if (!mounted) return;
      setState(() {
        _data = detail ?? _data;
      });
      if (detail != null && detail["is_read"] != true) {
        try {
          await _service.markNotificationRead(
            id: widget.notificationId,
            isRead: true,
          );
          if (mounted) {
            setState(() {
              _data = {...detail, "is_read": true};
            });
          }
        } catch (_) {
          // Mark read failure should not block reading.
        }
      }
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _toggleRead() async {
    final current = _data;
    if (current == null || _busy) return;
    final next = current["is_read"] != true;
    setState(() => _busy = true);
    try {
      await _service.markNotificationRead(
        id: widget.notificationId,
        isRead: next,
      );
      if (!mounted) return;
      setState(() {
        _data = {...current, "is_read": next};
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
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
    setState(() => _busy = true);
    try {
      await _service.deleteNotification(widget.notificationId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _data != null;
    final title = _data?['title']?.toString().trim();
    final body = _data?['body']?.toString().trim();
    final dateOnly = formatNotificationDateOnly(
      _data?['created_at']?.toString(),
    );
    final timeOnly = formatNotificationTimeOnly(
      _data?['created_at']?.toString(),
    );
    final isRead = _data?['is_read'] == true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text("Bildirim"),
        actions: [
          IconButton(
            tooltip: isRead ? "Okunmadı yap" : "Okundu yap",
            onPressed: _loading || _busy ? null : _toggleRead,
            icon: Icon(
              isRead
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
            ),
          ),
          IconButton(
            tooltip: "Sil",
            onPressed: _loading || _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && !hasData
            ? const Center(child: CircularProgressIndicator())
            : hasData
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? const Color(0xFFEFFAF3)
                                      : const Color(0xFFFFF0EC),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isRead
                                      ? Icons.notifications_none_outlined
                                      : Icons.notifications_active_outlined,
                                  color: isRead
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFE74C3C),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isRead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF0EC),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          "Okunmadı",
                                          style: TextStyle(
                                            color: Color(0xFFE74C3C),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    Text(
                                      title?.isNotEmpty == true
                                          ? title!
                                          : _fallbackTitle(),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _metaChip(
                                icon: Icons.schedule_outlined,
                                label: dateOnly,
                                background: const Color(0xFFF8FAFC),
                                foreground: const Color(0xFF4B5563),
                                border: const Color(0xFFE5E7EB),
                              ),
                              _metaChip(
                                icon: Icons.event_note_outlined,
                                label: timeOnly,
                                background: const Color(0xFFF8FAFC),
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
                                foreground: isRead
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE74C3C),
                                border: isRead
                                    ? const Color(0xFFBFE8CB)
                                    : const Color(0xFFF3C0B6),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          SelectableText(
                            body?.isNotEmpty == true ? body! : _fallbackBody(),
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : _emptyState(),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            const Text(
              "Bildirim bulunamadı",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              "Bu bildirim silinmiş olabilir ya da erişim geçici olarak bulunamıyor.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Geri Dön"),
            ),
          ],
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
}
