import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/admin/admin_magazine_service.dart';
import '../../services/admin/admin_magazine_type_price_service.dart';
import '../../services/admin/admin_magazine_type_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/safe_image.dart';
import 'admin_magazine_detail_page.dart';

class AdminMagazinesPage extends StatefulWidget {
  const AdminMagazinesPage({super.key});

  @override
  State<AdminMagazinesPage> createState() => _AdminMagazinesPageState();
}

class _AdminMagazinesPageState extends State<AdminMagazinesPage> {
  final AdminMagazineService _service = AdminMagazineService();
  final AdminMagazineTypeService _typeService = AdminMagazineTypeService();
  final AdminMagazineTypePriceService _priceService = AdminMagazineTypePriceService();
  final TextEditingController _searchCtrl = TextEditingController();
  final UploadService _uploadService = UploadService();

  List<Map<String, dynamic>> _magazines = [];
  List<Map<String, dynamic>> _filtered = [];

  String formatAsMoney(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return "";
    final padded = digits.padLeft(3, "0");
    final l = padded.length;
    String integerPart = padded.substring(0, l - 2);
    final decimalPart = padded.substring(l - 2);
    integerPart = integerPart.replaceFirst(RegExp(r'^0+'), '');
    if (integerPart.isEmpty) integerPart = "0";
    return "$integerPart.$decimalPart";
  }

  double? _parsePrice(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(",", "."));
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    final two = (int v) => v.toString().padLeft(2, '0');
    return "${two(dt.hour)}:${two(dt.minute)} ${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  @override
  void initState() {
    super.initState();
    _loadMagazines();
  }

  Future<void> _loadMagazines() async {
    try {
      final list = await _service.getMagazines();
      setState(() {
        _magazines = list;
        _filtered = list;
      });
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Future<void> _pickImage(
    TextEditingController controller, {
    required void Function(Uint8List bytes, String name) onPicked,
  }) async {
    try {
      final picked = await AssetImagePicker.pickImageFile();
      if (picked == null) return;
      onPicked(picked.bytes, picked.name);
      controller.text = picked.name;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Seçildi: ${picked.name}")),
        );
      }
    } catch (e) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("İşlem başarısız"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tamam"),
            ),
          ],
        ),
      );
    }
  }

  void _filter(String value) {
    final q = value.toLowerCase();
    setState(() {
      _filtered = _magazines.where((m) {
        return (m["name"] ?? "").toString().toLowerCase().contains(q) ||
            (m["category"] ?? "").toString().toLowerCase().contains(q);
      }).toList();
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

  Future<void> _showAddOrEditDialog({Map<String, dynamic>? magazine}) async {
    final isEdit = (magazine?["id"]) != null;
    final formKey = GlobalKey<FormState>();
    final magazineId = magazine?["id"] as int?;
    List<Map<String, dynamic>> types = [];
    Map<int, String> priceByType = {};

    try {
      types = await _typeService.getAll();
      if (types.isEmpty) {
        await _showError("Dergi tipi bulunamadı. Önce dergi tipleri oluşturun.");
        return;
      }
      if (isEdit && magazineId != null) {
        final prices = await _priceService.getByMagazine(magazineId);
        for (final p in prices) {
          final typeId = p["magazine_type_id"] as int?;
          if (typeId == null) continue;
          priceByType[typeId] = (p["price"] ?? "").toString();
        }
      }
    } catch (e) {
      await _showError(e.toString());
      return;
    }

    final nameCtrl = TextEditingController(text: magazine?["name"] ?? "");
    final categoryCtrl =
        TextEditingController(text: magazine?["category"] ?? "");
    final coverCtrl =
        TextEditingController(text: magazine?["cover_image_url"] ?? "");
    final descCtrl =
        TextEditingController(text: magazine?["description"] ?? "");
    final priceControllers = <int, TextEditingController>{};
    for (final type in types) {
      final typeId = type["id"] as int?;
      if (typeId == null) continue;
      priceControllers[typeId] = TextEditingController(text: priceByType[typeId] ?? "");
    }
    String period = _normalizePeriod(magazine?["period"]) ?? "1m";

    Uint8List? pickedCoverBytes;
    String? pickedCoverName;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Dergiyi Düzenle" : "Yeni Dergi Oluştur"),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Dergi Adı"),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? "Bu alan zorunlu" : null,
                ),
                TextFormField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: "Kategori"),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? "Bu alan zorunlu" : null,
                ),
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: "Periyot"),
                  items: const [
                    DropdownMenuItem(value: "1m", child: Text("Aylık")),
                    DropdownMenuItem(value: "3m", child: Text("3 Aylık")),
                    DropdownMenuItem(value: "6m", child: Text("6 Aylık")),
                    DropdownMenuItem(value: "12m", child: Text("12 Aylık")),
                  ],
                  onChanged: (v) => period = v ?? "1m",
                ),
                TextFormField(
                  controller: coverCtrl,
                  readOnly: true,
                  onTap: () => _pickImage(
                    coverCtrl,
                    onPicked: (bytes, name) {
                      pickedCoverBytes = bytes;
                      pickedCoverName = name;
                    },
                  ),
                  decoration: InputDecoration(
                    labelText: "Kapak Görseli (PNG/JPG/WEBP)",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: () => _pickImage(
                        coverCtrl,
                        onPicked: (bytes, name) {
                          pickedCoverBytes = bytes;
                          pickedCoverName = name;
                        },
                      ),
                    ),
                  ),
                ),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: "Açıklama (opsiyonel)",
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Dergi Tipi Fiyatları",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                ...types.map((type) {
                  final typeId = type["id"] as int?;
                  if (typeId == null || !priceControllers.containsKey(typeId)) {
                    return const SizedBox.shrink();
                  }
                  final title = (type["title"] ?? "").toString();
                  final months = type["duration_months"]?.toString() ?? "-";
                  final ctrl = priceControllers[typeId]!;
                  return TextFormField(
                    controller: ctrl,
                    onChanged: (value) {
                      final formatted = formatAsMoney(value);
                      ctrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    },
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: title.isNotEmpty ? title : "$months ay",
                      helperText: "$months ay",
                      prefixText: "₺ ",
                    ),
                    validator: (v) {
                      final price = _parsePrice(v ?? "");
                      if (price == null) return "Geçerli bir fiyat girin";
                      if (price <= 0) return "Fiyat 0'dan büyük olmalı";
                      return null;
                    },
                  );
                }),
              ],
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

              final typePrices = <Map<String, dynamic>>[];
              for (final type in types) {
                final typeId = type["id"] as int?;
                if (typeId == null || !priceControllers.containsKey(typeId)) continue;
                final price = _parsePrice(priceControllers[typeId]!.text);
                if (price == null || price <= 0) {
                  await _showError("Tüm dergi tipleri için geçerli fiyat girin");
                  return;
                }
                typePrices.add({
                  "magazine_type_id": typeId,
                  "price": price,
                  "is_active": true,
                  "sort_order": (type["sort_order"] as num?)?.toInt() ?? 0,
                });
              }

              final payload = {
                "id": magazine?["id"],
                "name": nameCtrl.text.trim(),
                "category": categoryCtrl.text.trim(),
                "period": period,
                "cover_image_url": coverCtrl.text.trim().isEmpty
                    ? null
                    : coverCtrl.text.trim(),
                "description": descCtrl.text.trim(),
              };

              Navigator.pop(context);

              try {
                String? coverUrl = payload["cover_image_url"] as String?;
                if (pickedCoverBytes != null && pickedCoverName != null) {
                  coverUrl = await _uploadService.uploadPublic(
                    type: UploadFileType.magazine,
                    bytes: pickedCoverBytes!,
                    filename: pickedCoverName!,
                  );
                }

                int savedId;
                if (isEdit) {
                  savedId = payload["id"] as int;
                  await _service.updateMagazine(
                    id: savedId,
                    name: payload["name"] as String,
                    category: payload["category"] as String,
                    period: payload["period"] as String,
                    coverImageUrl: coverUrl,
                    description: (payload["description"] as String).isEmpty
                        ? null
                        : payload["description"] as String,
                  );
                } else {
                  savedId = await _service.addMagazine(
                    name: payload["name"] as String,
                    category: payload["category"] as String,
                    period: payload["period"] as String,
                    coverImageUrl: coverUrl,
                    description: (payload["description"] as String).isEmpty
                        ? null
                        : payload["description"] as String,
                  );
                }

                final items = typePrices
                    .map((p) => {
                          "magazine_id": savedId,
                          ...p,
                        })
                    .toList();
                await _priceService.replacePrices(magazineId: savedId, prices: items);

                await _loadMagazines();
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _showAddOrEditDialog(magazine: payload),
                  );
                }
                return;
              }

              // Ensure list is fresh after dialog closes
              if (mounted) {
                await _loadMagazines();
              }
            },
            child: Text(isEdit ? "Kaydet" : "Oluştur",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMagazine(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Dergi Sil"),
        content: const Text("Bu dergiyi silmek istediğinize emin misiniz?"),
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
      await _service.deleteMagazine(id);
      await _loadMagazines();
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
              "Dergiler",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Dergi Oluştur",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _showAddOrEditDialog,
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _searchCtrl,
          onChanged: _filter,
          decoration: InputDecoration(
            hintText: "Dergi adı veya kategori ara...",
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
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              Colors.grey.shade100,
                            ),
                            columns: const [
                              DataColumn(label: Text("#")),
                              DataColumn(label: Text("Kapak")),
                              DataColumn(label: Text("Ad")),
                              DataColumn(label: Text("Kategori")),
                              DataColumn(label: Text("Periyot")),
                              DataColumn(label: Text("Oluşturma")),
                              DataColumn(label: Text("İşlem")),
                            ],
                            rows: _filtered.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final m = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text(index.toString())),
                                  DataCell(_buildCoverCell(m["cover_image_url"])),
                                  DataCell(Text(m["name"] ?? "")),
                                  DataCell(Text(m["category"] ?? "")),
                                  DataCell(_buildPeriodChip(m["period"])),
                                  DataCell(
                                    Text(_formatDateTime(m["created_at"])),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.folder_open,
                                              color: Colors.blue),
                                          tooltip: "Detay / Sayılar",
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AdminMagazineDetailPage(
                                                  magazine: m,
                                                ),
                                              ),
                                            );
                                            await _loadMagazines();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.orange),
                                          onPressed: () =>
                                              _showAddOrEditDialog(
                                                  magazine: m),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteMagazine(m["id"] as int),
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

  Widget _buildCoverCell(String? url) {
    if (url == null || url.isEmpty) {
      return const SizedBox(
        width: 40,
        height: 60,
        child: ColoredBox(
          color: Color(0xFFE0E0E0),
          child: Icon(Icons.menu_book_outlined, size: 22),
        ),
      );
    }

    final normalized = UploadService.normalizeUrl(url);
    final isNetwork =
        normalized.startsWith("http://") || normalized.startsWith("https://");

    final fallback = const SizedBox(
      width: 40,
      height: 60,
      child: ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Icon(Icons.broken_image, size: 20),
      ),
    );

    final imageWidget = isNetwork
        ? safeImage(
            normalized,
            width: 40,
            height: 60,
            fit: BoxFit.cover,
            fallbackIcon: Icons.broken_image,
          )
        : Image.asset(
            normalized,
            width: 40,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: imageWidget,
    );
  }

  Widget _buildPeriodChip(String? period) {
    final normalized = _normalizePeriod(period);
    final label = switch (normalized) {
      "1m" => "Aylık",
      "3m" => "3 Aylık",
      "6m" => "6 Aylık",
      "12m" => "12 Aylık",
      _ => "-",
    };

    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFFFEBEE),
      labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      padding: EdgeInsets.zero,
    );
  }

  String? _normalizePeriod(dynamic period) {
    final normalized = period?.toString().toLowerCase();
    return normalized;
  }
}
