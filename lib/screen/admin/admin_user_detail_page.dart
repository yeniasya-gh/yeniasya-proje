import 'package:flutter/material.dart';

import '../../services/address_service.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/order_service.dart';
import 'admin_loading_indicator.dart';

class AdminUserDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailPage({super.key, required this.user});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final AdminUserService _adminService = AdminUserService();
  final OrderService _orderService = OrderService();
  final AddressService _addressService = AddressService();

  bool _loading = true;
  List<Map<String, dynamic>> _access = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final userId = widget.user["id"] as int;
    try {
      final results = await Future.wait([
        _adminService.getAllAccess(userId),
        _orderService.getOrdersWithItems(userId),
        _addressService.getAddresses(userId.toString()),
      ]);
      _access = results[0] as List<Map<String, dynamic>>;
      _orders = results[1] as List<Map<String, dynamic>>;
      _addresses = results[2] as List<Map<String, dynamic>>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final paidOrders = _orders
        .where((o) => (o["status"] ?? "").toString().toLowerCase() == "paid")
        .toList();
    final activeCount = _access.where((a) => a["is_active"] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Text("${user["name"] ?? "Kullanıcı"} Detay"),
      ),
      body: _loading
          ? const AdminLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle("Kullanıcı Bilgileri"),
                _infoCard([
                  _infoRow("ID", user["id"]?.toString() ?? "-"),
                  _infoRow("Ad Soyad", user["name"] ?? "-"),
                  _infoRow("E-posta", user["email"] ?? "-"),
                  _infoRow("Telefon", user["phone"] ?? "-"),
                  _infoRow("Rol", user["role"] ?? "-"),
                ]),
                const SizedBox(height: 18),
                _sectionTitle("Abonelikler"),
                _infoCard([
                  _infoRow("Toplam", _access.length.toString()),
                  _infoRow("Aktif", activeCount.toString()),
                ]),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: "Abonelik bulunamadı.",
                  items: _access,
                  itemBuilder: (item) {
                    final type = _accessTypeLabel((item["item_type"] ?? "").toString());
                    final itemId = item["item_id"]?.toString() ?? "-";
                    final started = _formatDateShort(item["started_at"]);
                    final expires = _formatDateShort(item["expires_at"]);
                    final isActive = item["is_active"] == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(type),
                      subtitle: Text("Başlangıç: $started  •  Bitiş: $expires"),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("ID: $itemId", style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(isActive ? "Aktif" : "Pasif",
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _sectionTitle("Başarılı Siparişler"),
                _infoCard([
                  _infoRow("Toplam", paidOrders.length.toString()),
                ]),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: "Başarılı sipariş bulunamadı.",
                  items: paidOrders,
                  itemBuilder: (order) {
                    final id = order["id"]?.toString() ?? "-";
                    final total = order["total_paid"]?.toString() ?? "0";
                    final created = _formatDateShort(order["created_at"]);
                    final items = (order["order_items"] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Sipariş #$id"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tarih: $created  •  Toplam: ₺$total"),
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...items.map((it) {
                              final title = it["title"]?.toString() ?? "-";
                              final qty = it["quantity"]?.toString() ?? "1";
                              final line = it["line_total"]?.toString() ??
                                  it["unit_price"]?.toString() ??
                                  "-";
                              return Text("• $title x$qty (₺$line)");
                            }),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _sectionTitle("Adresler"),
                _infoCard([
                  _infoRow("Toplam", _addresses.length.toString()),
                ]),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: "Adres bulunamadı.",
                  items: _addresses,
                  itemBuilder: (a) {
                    final name = a["address_name"] ?? "-";
                    final type = (a["address_type"] ?? "").toString().toLowerCase() == "kurumsal"
                        ? "Kurumsal"
                        : "Bireysel";
                    final full = a["full_address"] ?? "-";
                    final tax = (a["tax_address"] ?? "").toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("$name ($type)"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(full),
                          if (tax.isNotEmpty) Text("Vergi Adresi: $tax"),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _listCard({
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic> item) itemBuilder,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(emptyText),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  itemBuilder(items[i]),
                  if (i != items.length - 1) const Divider(height: 1),
                ]
              ],
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _accessTypeLabel(String type) {
    switch (type) {
      case "book":
        return "Kitap";
      case "magazine":
        return "E-dergi";
      case "magazine_issue":
        return "Dergi Sayısı";
      case "newspaper_subscription":
        return "Gazete Aboneliği";
      case "ek":
        return "Ek";
      default:
        return type;
    }
  }

  String _formatDateShort(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }
}
