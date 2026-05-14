import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/admin/admin_order_service.dart';
import '../../services/error/error_manager.dart';
import '../../utils/purchase_channel_labels.dart';
import '../order/order_detail_screen.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _service = AdminOrderService();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  Timer? _searchDebounce;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  String _statusFilter = "all";
  String _sort = "created_desc";
  DateTime? _startDate;
  DateTime? _endDate;

  static const _statusFilters = [
    ("all", "Tümü"),
    ("pending", "Beklemede"),
    ("paid", "Ödendi"),
    ("shipped", "Kargoda"),
    ("delivered", "Teslim"),
    ("canceled", "İptal"),
    ("refunded", "İade"),
  ];

  static const _sortOptions = [
    ("created_desc", "En yeni"),
    ("created_asc", "En eski"),
    ("total_desc", "Tutar azalan"),
    ("total_asc", "Tutar artan"),
  ];

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

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
      final result = await _service.listOrdersPage(
        keyword: _searchCtrl.text,
        status: _statusFilter,
        sort: _sort,
        startDate: _startDate == null ? null : _formatDateIso(_startDate!),
        endDate: _endDate == null ? null : _formatDateIso(_endDate!),
        page: requestedPage,
        pageSize: _pageSize,
      );
      final totalPages = _totalPagesFor(result.totalCount, _pageSize);
      if (requestedPage > totalPages && totalPages > 0) {
        await _load(page: totalPages);
        return;
      }
      setState(() {
        _orders = result.items;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Siparişler",
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
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: "Sipariş ID, kullanıcı adı, e-posta veya ödeme bilgisi ara",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: _searchCtrl.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _load(page: 1);
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
                  onSelected: (_) {
                    if (_statusFilter == filter.$1) return;
                    setState(() => _statusFilter = filter.$1);
                    _load(page: 1);
                  },
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
              onChanged: (value) {
                if (value == null || _sort == value) return;
                setState(() => _sort = value);
                _load(page: 1);
              },
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
                if (value == null || _pageSize == value) return;
                setState(() => _pageSize = value);
                _load(page: 1);
              },
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: _pickStartDate,
              icon: const Icon(Icons.date_range),
              label: Text(
                _startDate == null ? "Başlangıç tarihi" : _formatDateOnly(_startDate!),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _pickEndDate,
              icon: const Icon(Icons.event),
              label: Text(
                _endDate == null ? "Bitiş tarihi" : _formatDateOnly(_endDate!),
              ),
            ),
            const SizedBox(width: 8),
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _load(page: 1);
                },
                child: const Text("Tarihi temizle"),
              ),
          ],
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _loading
                ? const SizedBox.shrink()
                : _orders.isEmpty
                ? const Center(child: Text("Sipariş bulunamadı."))
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(
                                    Colors.grey.shade100,
                                  ),
                                  columnSpacing: 24,
                                  dataRowHeight: 52,
                                  columns: const [
                                    DataColumn(label: Text("#")),
                                    DataColumn(label: Text("Kullanıcı")),
                                    DataColumn(label: Text("Tutar")),
                                    DataColumn(label: Text("Ödeme Kanalı")),
                                    DataColumn(label: Text("Durum")),
                                    DataColumn(label: Text("Tarih")),
                                    DataColumn(label: Text("Detay")),
                                  ],
                                  rows: _orders.map((o) {
                                    final total = (o["total_paid"] ?? 0).toString();
                                    final userName =
                                        o["user"]?["name"] ??
                                        o["user"]?["email"] ??
                                        "-";
                                    final paymentChannel =
                                        PurchaseChannelLabels.orderChannelLabel(o);
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(o["id"]?.toString() ?? "")),
                                        DataCell(Text(userName)),
                                        DataCell(Text("₺$total")),
                                        DataCell(Text(paymentChannel)),
                                        DataCell(
                                          Text(
                                            _statusLabel(
                                              o["status"]?.toString() ?? "",
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(_formatDate(o["created_at"]))),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(
                                              Icons.open_in_new,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () {
                                              final id = _asInt(o["id"]);
                                              if (id != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => OrderDetailScreen(
                                                      orderId: id,
                                                    ),
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
                      const SizedBox(height: 12),
                      _paginationBar(),
                    ],
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

  String _formatDateOnly(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(date.day)}.${two(date.month)}.${date.year}";
  }

  String _formatDateIso(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return "${date.year}-${two(date.month)}-${two(date.day)}";
  }

  int _totalPagesFor(int totalCount, int pageSize) {
    if (totalCount <= 0) return 0;
    final safePageSize = pageSize < 1 ? 1 : pageSize;
    return ((totalCount + safePageSize - 1) ~/ safePageSize);
  }

  void _goToPage(int page) {
    final totalPages = _totalPagesFor(_totalCount, _pageSize);
    final safePage = page.clamp(1, totalPages == 0 ? 1 : totalPages);
    if (safePage == _currentPage) return;
    _load(page: safePage);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? _endDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
    _load(page: 1);
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      if (_startDate != null && _startDate!.isAfter(_endDate!)) {
        _startDate = _endDate;
      }
    });
    _load(page: 1);
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
}
