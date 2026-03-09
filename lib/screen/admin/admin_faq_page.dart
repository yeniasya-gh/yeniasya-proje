import 'package:flutter/material.dart';

import '../../services/admin/admin_faq_service.dart';
import '../../services/error/error_manager.dart';

class AdminFaqPage extends StatefulWidget {
  const AdminFaqPage({super.key});

  @override
  State<AdminFaqPage> createState() => _AdminFaqPageState();
}

class _AdminFaqPageState extends State<AdminFaqPage> {
  final AdminFaqService _service = AdminFaqService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  int _itemId(Map<String, dynamic> item) {
    final raw = item["id"];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.parse(raw.toString());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return "-";
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    String two(int value) => value.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getAll();
      if (!mounted) return;
      setState(() {
        _items = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _showError(e.toString());
    }
  }

  void _filter(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _items;
      } else {
        _filtered = _items.where((item) {
          final title = (item["title"] ?? "").toString().toLowerCase();
          final description = (item["description"] ?? "")
              .toString()
              .toLowerCase();
          return title.contains(q) || description.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _showError(String rawError) {
    final parsed = ErrorManager.parseGraphQLError(
      rawError.replaceFirst("Exception:", "").trim(),
    );
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hata"),
        content: Text(parsed),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddOrEditDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(
      text: item?["title"]?.toString() ?? "",
    );
    final descriptionCtrl = TextEditingController(
      text: item?["description"]?.toString() ?? "",
    );
    final sortOrderCtrl = TextEditingController(
      text: item?["sort_order"]?.toString() ?? "0",
    );
    bool isActive = item?["is_active"] == true;
    if (!isEdit) {
      isActive = true;
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "SSS Düzenle" : "Yeni SSS Ekle"),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: "Başlık"),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Başlık zorunlu"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionCtrl,
                      decoration: const InputDecoration(labelText: "Açıklama"),
                      minLines: 4,
                      maxLines: 8,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Açıklama zorunlu"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: sortOrderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Sıra",
                        helperText: "Küçük sayı üstte gösterilir.",
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Sıra zorunlu";
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return "Geçerli bir sayı girin";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Aktif"),
                      subtitle: const Text(
                        "Pasif kayıtlar kullanıcıya gösterilmez.",
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Kapat"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                try {
                  final sortOrder = int.parse(sortOrderCtrl.text.trim());
                  if (isEdit) {
                    await _service.update(
                      id: _itemId(item),
                      title: titleCtrl.text.trim(),
                      description: descriptionCtrl.text.trim(),
                      sortOrder: sortOrder,
                      isActive: isActive,
                    );
                  } else {
                    await _service.add(
                      title: titleCtrl.text.trim(),
                      description: descriptionCtrl.text.trim(),
                      sortOrder: sortOrder,
                      isActive: isActive,
                    );
                  }
                  await _load();
                } catch (e) {
                  await _showError(e.toString());
                }
              },
              child: Text(
                isEdit ? "Kaydet" : "Oluştur",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("SSS Sil"),
        content: const Text("Bu SSS kaydını silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.delete(id);
      await _load();
    } catch (e) {
      await _showError(e.toString());
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
              "SSS Yönetimi",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showAddOrEditDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "SSS Ekle",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _searchCtrl,
          onChanged: _filter,
          decoration: InputDecoration(
            hintText: "Başlık veya açıklama ara...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.quiz_outlined,
                            size: 48,
                            color: Colors.black38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _items.isEmpty
                                ? "Henüz eklenmiş SSS kaydı yok."
                                : "Aramanıza uygun SSS kaydı bulunamadı.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("#")),
                              DataColumn(label: Text("Başlık")),
                              DataColumn(label: Text("Açıklama")),
                              DataColumn(label: Text("Sıra")),
                              DataColumn(label: Text("Durum")),
                              DataColumn(label: Text("Güncelleme")),
                              DataColumn(label: Text("İşlem")),
                            ],
                            rows: _filtered.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final item = entry.value;
                              final description =
                                  item["description"]?.toString() ?? "";
                              return DataRow(
                                cells: [
                                  DataCell(Text(index.toString())),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 220,
                                      ),
                                      child: Text(
                                        item["title"]?.toString() ?? "",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 320,
                                      ),
                                      child: Text(
                                        description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(item["sort_order"]?.toString() ?? "0"),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        item["is_active"] == true
                                            ? "Aktif"
                                            : "Pasif",
                                      ),
                                      backgroundColor: item["is_active"] == true
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFFFEBEE),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_formatDateTime(item["updated_at"])),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () =>
                                              _showAddOrEditDialog(item: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _delete(_itemId(item)),
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
          ),
        ),
      ],
    );
  }
}
