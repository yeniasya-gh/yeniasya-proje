import 'package:flutter/material.dart';
import '../../services/admin/admin_review_service.dart';
import '../../services/error/error_manager.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  final _service = AdminReviewService();
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // ürün filtresi yok: hepsini çek
      final data = await _service.getAll();
      setState(() => _reviews = data);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _service.updateStatus(id: id, status: status);
      await _load();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await _service.deleteReview(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum silindi")));
      }
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Yorumlar", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reviews.isEmpty
                  ? const Center(child: Text("Yorum bulunamadı."))
                  : _table(),
        ),
      ],
    );
  }

  Widget _table() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                columnSpacing: 18,
                dataRowHeight: 64,
                columns: const [
                  DataColumn(label: Text("Ürün Tipi")),
                  DataColumn(label: Text("Ürün")),
                  DataColumn(label: Text("Kullanıcı")),
                  DataColumn(label: Text("Puan")),
                  DataColumn(label: Text("Yorum")),
                  DataColumn(label: Text("Durum")),
                  DataColumn(label: Text("Tarih")),
                  DataColumn(label: Text("Aksiyon")),
                ],
                rows: _reviews.map((r) {
                  final status = (r["status"] ?? "").toString();
                  return DataRow(
                    cells: [
                      DataCell(Text(_productTypeLabel(r["product_type"]))),
                      DataCell(Text(_productName(r))),
                      DataCell(Text((r["user_name"] ?? r["user_email"] ?? "Kullanıcı #${r["user_id"] ?? "-"}").toString())),
                      DataCell(Text("⭐ ${r["rating"] ?? "-"}")),
                      DataCell(SizedBox(width: 240, child: Text(r["comment"]?.toString() ?? "-", maxLines: 2, overflow: TextOverflow.ellipsis))),
                      DataCell(_statusChip(status)),
                      DataCell(Text(_formatDate(r["created_at"]))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              tooltip: "Onayla",
                              onPressed: status == "published" ? null : () => _updateStatus(r["id"] as int, "published"),
                            ),
                            IconButton(
                              icon: const Icon(Icons.block, color: Colors.red),
                              tooltip: "Reddet",
                              onPressed: status == "rejected" ? null : () => _updateStatus(r["id"] as int, "rejected"),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.black54),
                              tooltip: "Sil",
                              onPressed: () => _confirmDelete(r["id"] as int),
                            ),
                          ],
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
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case "published":
        color = Colors.green;
        label = "Onaylandı";
        break;
      case "rejected":
        color = Colors.red;
        label = "Reddedildi";
        break;
      default:
        color = Colors.orange;
        label = "Beklemede";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? "");
    if (parsed == null) return "-";
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(parsed.day)}.${two(parsed.month)}.${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}";
  }

  String _productTypeLabel(dynamic raw) {
    switch ((raw ?? "").toString()) {
      case "book":
        return "E-Kitap";
      case "magazine":
        return "E-Dergi";
      case "magazine_issue":
        return "E-Dergi Sayısı";
      case "newspaper_subscription":
        return "E-Gazete";
      default:
        return raw?.toString() ?? "-";
    }
  }

  String _productName(Map<String, dynamic> r) {
    return r["product_title"]?.toString() ?? "ID ${r["product_id"]?.toString() ?? "-"}";
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yorumu sil"),
        content: const Text("Bu yorumu silmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _delete(id);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }
}
