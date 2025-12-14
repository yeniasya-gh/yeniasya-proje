import 'package:flutter/material.dart';
import 'notification_list_screen.dart';

class NotificationMenuEntry extends StatelessWidget {
  const NotificationMenuEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.notifications_outlined, color: Colors.black54),
      title: const Text(
        "Bildirimler",
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationListScreen()),
        );
      },
    );
  }
}
