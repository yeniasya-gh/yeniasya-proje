import 'package:flutter/material.dart';

import '../../services/admin/admin_magazine_type_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/loading_manager.dart';
import 'admin_loading_indicator.dart';

class AdminMagazineTypesPage extends StatefulWidget {
  const AdminMagazineTypesPage({super.key});

  @override
  State<AdminMagazineTypesPage> createState() => _AdminMagazineTypesPageState();
}

class _AdminMagazineTypesPageState extends State<AdminMagazineTypesPage> {
  final _service = AdminMagazineTypeService();

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _types = [];

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getAll();
      list.sort((a, b) {
        final aOrder = (a["sort_order"] as num?)?.toInt() ?? 0;
        final bOrder = (b["sort_order"] as num?)?.toInt() ?? 0;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aId = (a["id"] as num?)?.toInt() ?? 0;
        final bId = (b["id"] as num?)?.toInt() ?? 0;
        return bId.compareTo(aId);
      });
      setState(() => _types = list);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sil"),
        content: const Text("Bu dergi tipini silmek istiyor musunuz?"),
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
    setState(() => _saving = true);
    try {
      await _service.delete(id);
      await _load();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final rootContext = context;
    final nextSortOrder = _types.isEmpty
        ? 1
        : (_types
                .map((e) => (e["sort_order"] as num?)?.toInt() ?? 0)
                .reduce((a, b) => a > b ? a : b)) +
            1;
    final titleCtrl = TextEditingController(text: initial?["title"]?.toString() ?? "");
    final durationCtrl = TextEditingController(
      text: initial?["duration_months"]?.toString() ?? "",
    );
    final sortCtrl = TextEditingController(
      text: initial?["sort_order"]?.toString() ?? nextSortOrder.toString(),
    );
    bool isActive = initial?["is_active"] as bool? ?? true;

    Future<void> submit(BuildContext sheetContext) async {
      final title = titleCtrl.text.trim();
      final duration = int.tryParse(durationCtrl.text.trim());
      final sortOrder = int.tryParse(sortCtrl.text.trim()) ?? 0;
      if (title.isEmpty || duration == null) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(content: Text("Başlık ve süre (ay) zorunlu")),
        );
        return;
      }
      try {
        if (!mounted) return;
        setState(() => _saving = true);
        Navigator.pop(sheetContext);
        if (initial == null) {
          await _service.create(
            title: title,
            durationMonths: duration,
            isActive: isActive,
            sortOrder: sortOrder,
          );
        } else {
          final typeId = _asInt(initial["id"]);
          if (typeId == null) {
            throw Exception("Geçersiz kayıt id'si");
          }
          await _service.update(
            id: typeId,
            title: title,
            durationMonths: duration,
            isActive: isActive,
            sortOrder: sortOrder,
          );
        }
        await _load();
      } catch (e) {
        final parsed = ErrorManager.parseGraphQLError(e.toString());
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text(parsed)));
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    initial == null ? "Dergi Tipi Ekle" : "Dergi Tipini Düzenle",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Başlık"),
              ),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Süre (ay)"),
              ),
              TextField(
                controller: sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Sıra"),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                onChanged: (val) => setSheetState(() => isActive = val),
                title: const Text("Aktif"),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => submit(sheetContext),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Dergi Tipleri", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                    ElevatedButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text("Yeni Tip"),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const AdminLoadingIndicator()
                  : ListView.separated(
                      itemCount: _types.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final item = _types[i];
                        final title = item["title"]?.toString() ?? "-";
                        final duration = item["duration_months"]?.toString() ?? "-";
                        final active = item["is_active"] == true;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text("$duration ay", style: const TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: active ? Colors.green.shade50 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  active ? "Aktif" : "Pasif",
                                  style: TextStyle(
                                    color: active ? Colors.green.shade700 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => _openEditor(initial: item),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: () {
                                  final typeId = _asInt(item["id"]);
                                  if (typeId == null) return;
                                  _delete(typeId);
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        AnimatedBuilder(
          animation: LoadingManager.instance,
          builder: (_, __) {
            if (!_saving || LoadingManager.instance.loading) return const SizedBox.shrink();
            return Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.15),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          },
        ),
      ],
    );
  }
}
