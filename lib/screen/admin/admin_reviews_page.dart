import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/admin/admin_review_service.dart';
import '../../services/error/error_manager.dart';
import 'admin_loading_indicator.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  final _service = AdminReviewService();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  Timer? _searchDebounce;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  String _statusFilter = "all";
  String _sort = "created_desc";

  static const _statusFilters = [
    ("all", "Tümü"),
    ("pending", "Beklemede"),
    ("published", "Onaylananlar"),
    ("rejected", "Reddedilenler"),
  ];

  static const _sortOptions = [
    ("created_desc", "En yeni"),
    ("created_asc", "En eski"),
    ("rating_desc", "En yüksek puan"),
    ("rating_asc", "En düşük puan"),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _load(page: 1);
      }
    });
  }

  Future<void> _load({int? page}) async {
    setState(() => _loading = true);
    try {
      final requestedPage = page ?? _currentPage;
      final result = await _service.listReviewsPage(
        keyword: _searchCtrl.text,
        status: _statusFilter,
        sort: _sort,
        page: requestedPage,
        pageSize: _pageSize,
      );
      final totalPages = _totalPagesFor(result.totalCount, _pageSize);
      if (requestedPage > totalPages && totalPages > 0) {
        await _load(page: totalPages);
        return;
      }
      setState(() {
        _reviews = result.items;
        _totalCount = result.totalCount;
        _currentPage = totalPages == 0 ? 1 : requestedPage;
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _service.updateStatus(id: id, status: status);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == "published" ? "Yorum onaylandı" : "Yorum reddedildi",
            ),
          ),
        );
      }
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await _service.deleteReview(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Yorum silindi")));
      }
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
  }

  int _totalPagesFor(int totalCount, int pageSize) {
    if (totalCount <= 0) return 0;
    final safePageSize = pageSize < 1 ? 1 : pageSize;
    return ((totalCount + safePageSize - 1) ~/ safePageSize);
  }

  void _setStatusFilter(String value) {
    if (_statusFilter == value) return;
    setState(() => _statusFilter = value);
    _load(page: 1);
  }

  void _setSort(String? value) {
    if (value == null || _sort == value) return;
    setState(() => _sort = value);
    _load(page: 1);
  }

  void _setPageSize(int value) {
    if (_pageSize == value) return;
    setState(() => _pageSize = value);
    _load(page: 1);
  }

  void _goToPage(int page) {
    final safeTotalPages = _totalPagesFor(_totalCount, _pageSize);
    final safePage = page.clamp(1, safeTotalPages == 0 ? 1 : safeTotalPages);
    if (safePage == _currentPage) return;
    _load(page: safePage);
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
              "Yorumlar",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Toplam: $_totalCount",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: "Yorum, kullanıcı veya ürün ara",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _load(page: 1);
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _statusFilters
              .map(
                (filter) => ChoiceChip(
                  label: Text(filter.$2),
                  selected: _statusFilter == filter.$1,
                  onSelected: (_) => _setStatusFilter(filter.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            DropdownButton<String>(
              value: _sort,
              underline: const SizedBox.shrink(),
              items: _sortOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.$1,
                      child: Text(option.$2),
                    ),
                  )
                  .toList(),
              onChanged: _setSort,
            ),
            const SizedBox(width: 16),
            DropdownButton<int>(
              value: _pageSize,
              underline: const SizedBox.shrink(),
              items: const [10, 20, 50]
                  .map(
                    (size) => DropdownMenuItem(
                      value: size,
                      child: Text("$size / sayfa"),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _setPageSize(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AdminLoadingIndicator()
              : _reviews.isEmpty
              ? const Center(child: Text("Yorum bulunamadı."))
              : Column(
                  children: [
                    Expanded(child: _table()),
                    const SizedBox(height: 12),
                    _paginationBar(),
                  ],
                ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  Colors.grey.shade100,
                ),
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
                  final status = (r["status"] ?? "").toString().trim().toLowerCase();
                  final reviewId = _reviewIdOf(r);
                  return DataRow(
                    onSelectChanged: (_) => _openReviewDetail(r),
                    cells: [
                      DataCell(Text(_productTypeLabel(r["product_type"]))),
                      DataCell(Text(_productName(r))),
                      DataCell(
                        Text(
                          (r["user_name"] ??
                                  r["user_email"] ??
                                  "Kullanıcı #${r["user_id"] ?? "-"}")
                              .toString(),
                        ),
                      ),
                      DataCell(Text("⭐ ${r["rating"] ?? "-"}")),
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: InkWell(
                            onTap: () => _openReviewDetail(r),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                r["comment"]?.toString() ?? "-",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(_statusChip(status)),
                      DataCell(Text(_formatDate(r["created_at"]))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.visibility_outlined,
                                color: Colors.blueGrey,
                              ),
                              tooltip: "Detay",
                              onPressed: () => _openReviewDetail(r),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              tooltip: "Onayla",
                              onPressed: reviewId == null || status == "published"
                                  ? null
                                  : () => _updateStatus(reviewId, "published"),
                            ),
                            IconButton(
                              icon: const Icon(Icons.block, color: Colors.red),
                              tooltip: "Reddet",
                              onPressed: reviewId == null || status == "rejected"
                                  ? null
                                  : () => _updateStatus(reviewId, "rejected"),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.black54,
                              ),
                              tooltip: "Sil",
                              onPressed: reviewId == null
                                  ? null
                                  : () => _confirmDelete(reviewId),
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

  Widget _paginationBar() {
    final totalPages = _totalPagesFor(_totalCount, _pageSize);
    if (totalPages <= 1) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text("Sayfa 1 / ${totalPages == 0 ? 1 : totalPages}"),
      );
    }

    final canPrev = _currentPage > 1;
    final canNext = _currentPage < totalPages;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Sayfa $_currentPage / $totalPages"),
        Row(
          children: [
            IconButton(
              onPressed: canPrev ? () => _goToPage(_currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: canNext ? () => _goToPage(_currentPage + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.trim().toLowerCase();
    Color color;
    String label;
    switch (normalized) {
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
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
        return "Kitap";
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
    return r["product_title"]?.toString() ??
        "ID ${r["product_id"]?.toString() ?? "-"}";
  }

  void _openReviewDetail(Map<String, dynamic> review) {
    final userLabel =
        (review["user_name"] ??
                review["user_email"] ??
                "Kullanıcı #${review["user_id"] ?? "-"}")
            .toString();
    final comment = review["comment"]?.toString().trim() ?? "-";
    final rating = review["rating"]?.toString() ?? "-";
    final status = (review["status"] ?? "").toString().trim().toLowerCase();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yorum Detayı"),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  "Ürün Tipi",
                  _productTypeLabel(review["product_type"]),
                ),
                _detailRow("Ürün", _productName(review)),
                _detailRow("Kullanıcı", userLabel),
                _detailRow("Puan", "⭐ $rating"),
                _detailRow("Durum", _statusLabel(status)),
                _detailRow("Tarih", _formatDate(review["created_at"])),
                const SizedBox(height: 12),
                const Text(
                  "Yorum",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SelectableText(comment.isEmpty ? "-" : comment),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case "published":
        return "Onaylandı";
      case "rejected":
        return "Reddedildi";
      default:
        return "Beklemede";
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yorumu sil"),
        content: const Text("Bu yorumu silmek istiyor musunuz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
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

  int? _reviewIdOf(Map<String, dynamic> review) {
    final raw = review["id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? "");
  }
}
