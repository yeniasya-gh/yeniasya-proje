import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';

class NotificationDetailScreen extends StatefulWidget {
  final int notificationId;

  const NotificationDetailScreen({super.key, required this.notificationId});

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
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await _service.getNotificationDetail(
        widget.notificationId,
      );
      if (!mounted) return;
      setState(() => _data = detail);
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
    final title = _data?['title'] ?? '';
    final body = _data?['body'] ?? '';
    final date = _data?['created_at']?.toString() ?? '';
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isRead)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "Okunmadı",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(date, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
