import 'package:flutter/material.dart';
import '../../services/admin/admin_promo_code_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/loading_manager.dart';
import 'admin_loading_indicator.dart';

class AdminPromoCodesPage extends StatefulWidget {
  const AdminPromoCodesPage({super.key});

  @override
  State<AdminPromoCodesPage> createState() => _AdminPromoCodesPageState();
}

class _AdminPromoCodesPageState extends State<AdminPromoCodesPage> {
  static const _scopeOptions = [
    ("Kitap", "book"),
    ("Dergi", "magazine"),
    ("Abonelik", "subscription"),
    ("Ek", "supplement"),
  ];

  final _service = AdminPromoCodeService();
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _percentCtrl = TextEditingController();
  final _usageLimitCtrl = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  final List<String> _selectedScopes = [];

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _promoCodes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _percentCtrl.dispose();
    _usageLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getPromoCodes();
      setState(() => _promoCodes = list);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Başlangıç ve bitiş tarihi seçin")),
      );
      return;
    }
    if (_startAt!.isAfter(_endAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bitiş tarihi başlangıçtan sonra olmalı")),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createPromoCode(
        code: _codeCtrl.text.trim(),
        discountPercent: double.parse(_percentCtrl.text.trim()),
        startsAt: _startAt!,
        endsAt: _endAt!,
        usageLimit: _usageLimitCtrl.text.trim().isEmpty
            ? null
            : int.parse(_usageLimitCtrl.text.trim()),
        applicableCategories: List<String>.from(_selectedScopes),
      );
      _codeCtrl.clear();
      _percentCtrl.clear();
      _usageLimitCtrl.clear();
      setState(() {
        _startAt = null;
        _endAt = null;
        _selectedScopes.clear();
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Promosyon kodu oluşturuldu")),
        );
      }
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(int id, bool active) async {
    try {
      await _service.toggleActive(id: id, isActive: active);
      await _load();
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
      await _service.deletePromoCode(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Kod silindi")));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Promosyon Kodları",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        _buildForm(),
        const SizedBox(height: 16),
        Expanded(child: _buildTable()),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Yeni kod oluştur",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: "Kod"),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Kod gerekli" : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _percentCtrl,
                    decoration: const InputDecoration(labelText: "% İndirim"),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final parsed = double.tryParse(v ?? "");
                      if (parsed == null) return "Geçerli oran girin";
                      if (parsed <= 0 || parsed > 100)
                        return "0-100 arası olmalı";
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _usageLimitCtrl,
                    decoration: const InputDecoration(
                      labelText: "Kullanım limiti (adet, opsiyonel)",
                      helperText: "Boş bırakırsanız limitsiz olur",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scopeOptions.map((option) {
                final label = option.$1;
                final value = option.$2;
                final selected = _selectedScopes.contains(value);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        if (!_selectedScopes.contains(value)) {
                          _selectedScopes.add(value);
                        }
                      } else {
                        _selectedScopes.remove(value);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              "Boş bırakırsanız tüm kategorilerde geçerli olur.",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Başlangıç",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startAt == null ? "Seçiniz" : _formatDate(_startAt!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Bitiş",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endAt == null ? "Seçiniz" : _formatDate(_endAt!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: AnimatedBuilder(
                      animation: LoadingManager.instance,
                      builder: (_, __) {
                        if (_saving && !LoadingManager.instance.loading) {
                          return const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          );
                        }
                        return const Text("Kaydet");
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_loading) {
      return const AdminLoadingIndicator();
    }
    if (_promoCodes.isEmpty) {
      return const Center(child: Text("Kayıtlı promosyon kodu yok."));
    }

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
                columnSpacing: 24,
                dataRowHeight: 56,
                columns: const [
                  DataColumn(label: Text("Kod")),
                  DataColumn(label: Text("Kapsam")),
                  DataColumn(label: Text("%")),
                  DataColumn(label: Text("Başlangıç")),
                  DataColumn(label: Text("Bitiş")),
                  DataColumn(label: Text("Kullanım")),
                  DataColumn(label: Text("Aktif")),
                  DataColumn(label: Text("Sil")),
                ],
                rows: _promoCodes.map((p) {
                  final id = p["id"];
                  final limit = p["usage_limit"];
                  final count = p["usage_count"] ?? 0;
                  final usageText = (limit == null || limit == 0)
                      ? "Limitsiz ($count)"
                      : "$count / $limit";

                  return DataRow(
                    cells: [
                      DataCell(Text(p["code"]?.toString() ?? "")),
                      DataCell(Text(_scopeLabel(p["applicable_categories"]))),
                      DataCell(Text("%${p["discount_percent"]}")),
                      DataCell(Text(_formatDateStr(p["starts_at"]))),
                      DataCell(Text(_formatDateStr(p["ends_at"]))),
                      DataCell(Text(usageText)),
                      DataCell(
                        Switch(
                          value: p["is_active"] == true,
                          onChanged: (v) {
                            if (id == null) return;
                            _toggle(id as int, v);
                          },
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: id == null
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Kodu sil"),
                                      content: const Text(
                                        "Bu promosyon kodunu silmek istiyor musunuz?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("İptal"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _delete(id as int);
                                          },
                                          child: const Text("Sil"),
                                        ),
                                      ],
                                    ),
                                  );
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
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startAt ?? now)
        : (_endAt ?? now.add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  String _formatDateStr(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? "");
    if (parsed == null) return "-";
    return _formatDate(parsed);
  }

  String _scopeLabel(dynamic raw) {
    final values = raw is Iterable
        ? raw
              .map((value) => value?.toString().trim() ?? "")
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
              .cast<String>()
        : <String>[];
    if (values.isEmpty) return "Tümü";
    return values.map((value) => _scopeDisplayLabel(value)).join(", ");
  }

  String _scopeDisplayLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case "book":
        return "Kitap";
      case "magazine":
        return "Dergi";
      case "subscription":
        return "Abonelik";
      case "supplement":
        return "Ek";
      default:
        return raw;
    }
  }
}
