import 'package:flutter/material.dart';
import '../../services/admin/admin_reports_service.dart';
import '../../services/error/error_manager.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  String _selectedType = "book";
  String _selectedMetric = "sales";
  final _service = AdminReportsService();
  ReportResult? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    _startDateCtrl.text = _fmt(start);
    _endDateCtrl.text = _fmt(now);
    _fetch();
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      controller.text = _fmt(picked);
    }
  }

  void _generateReport() {
    _fetch();
  }

  String _fmt(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _fetch() async {
    DateTime? start;
    DateTime? end;
    if (_startDateCtrl.text.isNotEmpty) {
      start = DateTime.tryParse(_startDateCtrl.text);
    }
    if (_endDateCtrl.text.isNotEmpty) {
      end = DateTime.tryParse(_endDateCtrl.text);
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchReport(
        type: _selectedType,
        start: start,
        end: end,
      );
      setState(() => _report = result);
    } catch (e) {
      final msg = ErrorManager.parseGraphQLError(e.toString());
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Raporlar",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_report != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryCards(_report!),
                const SizedBox(height: 16),
                _chartCard(_report!),
                const SizedBox(height: 16),
                _topTable(_report!),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: const Text("Rapor görmek için filtreleri seçip 'Raporu Oluştur'a basın."),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Filtreler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: "Tür", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "book", child: Text("Kitap")),
                    DropdownMenuItem(value: "magazine", child: Text("Dergi")),
                    DropdownMenuItem(value: "magazine_one", child: Text("Dergi Sayısı")),
                    DropdownMenuItem(value: "newspaper_subscription", child: Text("Gazete Abonelik")),
                  ],
                  onChanged: (v) => setState(() => _selectedType = v ?? "book"),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _selectedMetric,
                  decoration: const InputDecoration(labelText: "Metri̇k", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "sales", child: Text("Satış Adedi")),
                    DropdownMenuItem(value: "revenue", child: Text("Ciro")),
                    DropdownMenuItem(value: "avg_price", child: Text("Ortalama Fiyat")),
                  ],
                  onChanged: (v) => setState(() => _selectedMetric = v ?? "sales"),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _startDateCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(_startDateCtrl),
                  decoration: const InputDecoration(
                    labelText: "Başlangıç",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.date_range),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _endDateCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(_endDateCtrl),
                  decoration: const InputDecoration(
                    labelText: "Bitiş",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.date_range),
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _generateReport,
                label: const Text("Raporu Oluştur", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(ReportResult report) {
    final cards = [
      _StatCard(label: "Satış Adedi", value: report.count.toString()),
      _StatCard(label: "Ciro", value: _formatCurrency(report.revenue)),
      _StatCard(label: "Ortalama Fiyat", value: _formatCurrency(report.avgPrice)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: c,
              ))
          .toList(),
    );
  }

  Widget _chartCard(ReportResult report) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Günlük Ciro", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (report.series.isEmpty)
            const Text("Veri yok")
          else
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: report.series.map((p) {
                  final height = report.peakValue <= 0 ? 0.0 : (p.value / report.peakValue) * 180.0;
                  final label = p.label.split("-").sublist(1).join("-");
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(label, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topTable(ReportResult report) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("En Çok Getiren 10 Ürün", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (report.items.isEmpty)
            const Text("Kayıt bulunamadı")
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text("Ürün")),
                  DataColumn(label: Text("Adet")),
                  DataColumn(label: Text("Ciro")),
                ],
                rows: report.items.take(10).map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row["title"]?.toString() ?? "-")),
                    DataCell(Text(row["quantity"]?.toString() ?? "0")),
                    DataCell(Text(_formatCurrency(double.tryParse(row["line_total"]?.toString() ?? "0") ?? 0))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) => "₺${value.toStringAsFixed(2)}";
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
