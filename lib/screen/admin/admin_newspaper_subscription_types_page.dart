import 'package:flutter/material.dart';

import '../../services/admin/admin_newspaper_subscription_type_service.dart';
import '../../services/error/error_manager.dart';

class AdminNewspaperSubscriptionTypesPage extends StatefulWidget {
  const AdminNewspaperSubscriptionTypesPage({super.key});

  @override
  State<AdminNewspaperSubscriptionTypesPage> createState() => _AdminNewspaperSubscriptionTypesPageState();
}

class _AdminNewspaperSubscriptionTypesPageState extends State<AdminNewspaperSubscriptionTypesPage> {
  final _service = AdminNewspaperSubscriptionTypeService();

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _types = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getAll();
      setState(() => _types = list);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final rootContext = context;
    final titleCtrl = TextEditingController(text: initial?["title"]?.toString() ?? "");
    final durationCtrl =
        TextEditingController(text: initial?["duration_months"]?.toString() ?? "");
    final priceCtrl = TextEditingController(
      text: initial?["price"]?.toString() ?? "",
    );
    final sortCtrl = TextEditingController(
      text: initial?["sort_order"]?.toString() ?? "0",
    );
    bool isActive = initial?["is_active"] as bool? ?? true;

    Future<void> submit(BuildContext sheetContext) async {
      final title = titleCtrl.text.trim();
      final duration = int.tryParse(durationCtrl.text.trim());
      final price = double.tryParse(priceCtrl.text.trim());
      final sortOrder = int.tryParse(sortCtrl.text.trim()) ?? 0;
      if (title.isEmpty || duration == null || price == null) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(content: Text("Başlık, süre (ay) ve fiyat zorunlu")),
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
            price: price,
            isActive: isActive,
            sortOrder: sortOrder,
          );
        } else {
          await _service.update(
            id: initial["id"] as int,
            title: title,
            durationMonths: duration,
            price: price,
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
                    initial == null ? "Gazete Tipi Ekle" : "Gazete Tipini Düzenle",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Başlık"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Süre (ay)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Fiyat"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Sıra"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Aktif"),
                  const Spacer(),
                  Switch(
                    value: isActive,
                    onChanged: (val) => setSheetState(() => isActive = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text("İptal"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => submit(sheetContext),
                      child: const Text("Kaydet"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(int id) async {
    try {
      await _service.delete(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silindi")));
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
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Gazete Tipleri", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _types.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final item = _types[i];
                        final title = item["title"]?.toString() ?? "-";
                        final duration = item["duration_months"]?.toString() ?? "-";
                        final price = double.tryParse(item["price"]?.toString() ?? "0") ?? 0;
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
                              Text(
                                "₺${price.toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
                              ),
                              const SizedBox(width: 12),
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
                                onPressed: () => _delete(item["id"] as int),
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
        if (_saving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
