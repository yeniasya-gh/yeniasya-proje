import 'package:flutter/material.dart';
import '../../services/admin/admin_stats_service.dart';
import '../../services/error/error_manager.dart';

class AdminStatsDashboard extends StatefulWidget {
  const AdminStatsDashboard({super.key});

  @override
  State<AdminStatsDashboard> createState() => _AdminStatsDashboardState();
}

class _AdminStatsDashboardState extends State<AdminStatsDashboard> {
  final _service = AdminStatsService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchStats();
      setState(() => _stats = data);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parsed)),
        );
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Dashboard",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _loading
            ? const SizedBox.shrink()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard("Kitap Sayısı", _stats["books"], width: cardWidth),
                      _statCard("Dergi Sayısı", _stats["magazines"], width: cardWidth),
                      _statCard("Gazete Sayısı", _stats["newspapers"], width: cardWidth),
                      _statCard("Sipariş Sayısı", _stats["orders"], width: cardWidth),
                      _statCard("Kullanıcı Sayısı", _stats["users"], width: cardWidth),
                      _statCard("Bugünkü Sipariş", _stats["orders_today"], width: cardWidth),
                      _statCard("Son 1 Ay Sipariş", _stats["orders_last_month"], width: cardWidth),
                    ],
                  );
                },
              ),
      ],
    );
  }

  Widget _statCard(String title, dynamic value, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            (value ?? 0).toString(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
