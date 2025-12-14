import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';

class NotificationDetailScreen extends StatefulWidget {
  final int notificationId;

  const NotificationDetailScreen({super.key, required this.notificationId});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _service = NotificationService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await _service.getNotificationDetail(widget.notificationId);
      setState(() => _data = detail);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = _data?['title'] ?? '';
    final body = _data?['body'] ?? '';
    final date = _data?['created_at']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text("Bildirim"),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(date, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
      ),
    );
  }
}
