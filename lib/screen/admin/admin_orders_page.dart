import 'package:flutter/material.dart';

import '../../services/admin/admin_order_service.dart';
import '../../services/error/error_manager.dart';
import '../order/order_detail_screen.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _service = AdminOrderService();
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getAllOrders();
      setState(() {
        _orders = data;
        _filtered = data;
      });
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
            const Text("Siparişler", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          onChanged: _filter,
          decoration: InputDecoration(
            hintText: "Sipariş ID, kullanıcı adı veya e-posta ara",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: _loading
                ? const SizedBox.shrink()
                : _filtered.isEmpty
                    ? const Center(child: Text("Sipariş bulunamadı."))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                                columnSpacing: 24,
                                dataRowHeight: 52,
                                columns: const [
                                  DataColumn(label: Text("#")),
                                  DataColumn(label: Text("Kullanıcı")),
                                  DataColumn(label: Text("Tutar")),
                                  DataColumn(label: Text("Durum")),
                                  DataColumn(label: Text("Tarih")),
                                  DataColumn(label: Text("Detay")),
                                ],
                                rows: _filtered.map((o) {
                                  final total = (o["total_paid"] ?? 0).toString();
                                  final userName = o["user"]?["name"] ?? o["user"]?["email"] ?? "-";
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(o["id"]?.toString() ?? "")),
                                      DataCell(Text(userName)),
                                      DataCell(Text("₺$total")),
                                      DataCell(Text(_statusLabel(o["status"]?.toString() ?? ""))),
                                      DataCell(Text(_formatDate(o["created_at"]))),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, color: Colors.blue),
                                          onPressed: () {
                                            final id = o["id"];
                                            if (id != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => OrderDetailScreen(orderId: id as int),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
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

  void _filter(String value) {
    final q = value.toLowerCase();
    setState(() {
      _filtered = _orders.where((o) {
        final id = (o["id"] ?? "").toString().toLowerCase();
        final name = (o["user"]?["name"] ?? "").toString().toLowerCase();
        final email = (o["user"]?["email"] ?? "").toString().toLowerCase();
        return id.contains(q) || name.contains(q) || email.contains(q);
      }).toList();
    });
  }
}
