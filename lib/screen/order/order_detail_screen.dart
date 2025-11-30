import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../services/error/error_manager.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _orderService = OrderService();
  bool _loading = true;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await _orderService.getOrderDetail(widget.orderId);
      setState(() => _order = detail);
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
        title: Text("Sipariş #${widget.orderId}"),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _order == null
                ? const Center(child: Text("Sipariş bulunamadı."))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _itemsCard(),
                        const SizedBox(height: 12),
                        _summaryCard(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _summaryCard() {
    final status = _order?["status"]?.toString() ?? "-";
    final total = _order?["total_paid"]?.toString() ?? "0";
    final date = _formatDate(_order?["created_at"]);

    return Container(
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
              const Text("Sipariş Özeti", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          const SizedBox(height: 8),
          Text(date, style: const TextStyle(color: Colors.black54)),
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
    );
  }

  Widget _itemsCard() {
    final items = List<Map<String, dynamic>>.from(_order?["order_items"] ?? []);

    return Container(
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
          const Text("Ürünler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map((i) {
            final type = _typeLabel(i["product_type"]);
            final img = i["metadata"]?["image_url"]?.toString();
            final price = (i["line_total"] ?? i["unit_price"] ?? 0).toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 72,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                      image: img != null && img.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(img),
                              fit: BoxFit.cover,
                              onError: (_, __) {},
                            )
                          : null,
                    ),
                    child: img == null || img.isEmpty
                        ? const Icon(Icons.broken_image, color: Colors.black54)
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          "Adet: ${i["quantity"] ?? 1}  |  Tip: $type",
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₺$price",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text("Ürün bulunamadı.", style: TextStyle(color: Colors.black54)),
            ),
        ],
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

  String _typeLabel(dynamic raw) {
    switch ((raw ?? "").toString()) {
      case "book":
        return "Kitap";
      case "magazine":
        return "Dergi";
      case "magazine_issue":
        return "Dergi Sayısı";
      case "newspaper_subscription":
        return "Gazete";
      default:
        return raw?.toString() ?? "-";
    }
  }
}
