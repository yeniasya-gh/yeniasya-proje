import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/order_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/error/error_manager.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _orderService = OrderService();
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

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
      final orders = await _orderService.getOrders(userId);
      setState(() => _orders = orders);
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
        elevation: 1,
        foregroundColor: Colors.black,
        title: const Text("Sipariş Geçmişi"),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _orders.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 160),
                          Center(child: Text("Henüz siparişiniz yok.")),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) => _orderCard(_orders[i]),
                      ),
              ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = order["id"]?.toString() ?? "-";
    final total = order["total_paid"]?.toString() ?? "0";
    final status = (order["status"] ?? "paid").toString();
    final date = _formatDate(order["created_at"]);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order["id"] as int),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sipariş #$id", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(date, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Toplam", style: TextStyle(fontWeight: FontWeight.w600)),
                Text("₺$total", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return "Beklemede";
      case "paid":
        return "Ödendi";
      case "shipped":
        return "Kargoda";
      case "delivered":
        return "Teslim Edildi";
      case "canceled":
        return "İptal";
      case "refunded":
        return "İade";
      default:
        return status;
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.hour)}:${two(dt.minute)} ${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }
}
