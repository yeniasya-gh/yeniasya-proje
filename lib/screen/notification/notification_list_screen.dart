import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/error/error_manager.dart';
import 'notification_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final _service = NotificationService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

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
      final list = await _service.getUserNotifications(userId);
      setState(() => _items = list);
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
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 160),
                          Center(child: Text("Bildirim bulunamadı.")),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _notificationCard(_items[i]),
                      ),
              ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> n) {
    final title = n["title"] ?? "-";
    final body = n["body"] ?? "";
    final date = n["created_at"]?.toString() ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(date, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationDetailScreen(notificationId: n["id"] as int),
            ),
          );
        },
      ),
    );
  }
}
