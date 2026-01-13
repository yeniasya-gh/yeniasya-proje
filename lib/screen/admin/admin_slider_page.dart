import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/admin/admin_slider_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/safe_image.dart';
import 'admin_loading_indicator.dart';

class AdminSliderPage extends StatefulWidget {
  const AdminSliderPage({super.key});

  @override
  State<AdminSliderPage> createState() => _AdminSliderPageState();
}

class _AdminSliderPageState extends State<AdminSliderPage> {
  final AdminSliderService _service = AdminSliderService();
  final UploadService _uploadService = UploadService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getAll();
      setState(() {
        _all = list;
        _filtered = list;
      });
    } catch (e) {
      await _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String value) {
    final q = value.toLowerCase();
    setState(() {
      _filtered = _all.where((s) {
        return (s["title"] ?? "").toString().toLowerCase().contains(q) ||
            (s["subtitle"] ?? "").toString().toLowerCase().contains(q) ||
            (s["link_url"] ?? "").toString().toLowerCase().contains(q);
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

  Future<void> _showAddOrEditDialog({Map<String, dynamic>? slider}) async {
    final isEdit = slider != null;
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(text: slider?["title"] ?? "");
    final subtitleCtrl = TextEditingController(text: slider?["subtitle"] ?? "");
    final descriptionCtrl = TextEditingController(text: slider?["description"] ?? "");
    final linkCtrl = TextEditingController(text: slider?["link_url"] ?? "");
    final imageCtrl = TextEditingController(text: slider?["image_url"] ?? "");
    final sortCtrl = TextEditingController(text: (slider?["sort_order"] ?? 0).toString());
    bool isActive = slider?["is_active"] ?? true;

    Uint8List? pickedImageBytes;
    String? pickedImageName;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? "Slider Düzenle" : "Yeni Slider"),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: imageCtrl,
                    readOnly: true,
                    onTap: () => _pickImage(
                      imageCtrl,
                      onPicked: (bytes, name) {
                        pickedImageBytes = bytes;
                        pickedImageName = name;
                        setSt(() {});
                      },
                    ),
                    decoration: InputDecoration(
                      labelText: "Slider Görseli (PNG/JPG/WEBP)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => _pickImage(
                          imageCtrl,
                          onPicked: (bytes, name) {
                            pickedImageBytes = bytes;
                            pickedImageName = name;
                            setSt(() {});
                          },
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "Zorunlu" : null,
                  ),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: "Başlık"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Zorunlu" : null,
                  ),
                  TextFormField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(labelText: "Alt başlık"),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(labelText: "Açıklama"),
                    minLines: 3,
                    maxLines: 6,
                  ),
                  TextFormField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: "Link (opsiyonel)",
                      helperText: "Örn: https://... veya ?type=book&id=12",
                    ),
                  ),
                  TextFormField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Sıra"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Zorunlu";
                      return int.tryParse(v.trim()) == null ? "Sayı girin" : null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    onChanged: (val) => setSt(() => isActive = val),
                    title: const Text("Aktif"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                try {
                  String imageUrl = (slider?["image_url"] ?? imageCtrl.text).toString().trim();
                  if (pickedImageBytes != null && pickedImageName != null) {
                    imageUrl = await _uploadService.uploadPublic(
                      type: UploadFileType.slider,
                      bytes: pickedImageBytes!,
                      filename: pickedImageName!,
                    );
                  }

                  final sortOrder = int.tryParse(sortCtrl.text.trim()) ?? 0;
                  final title = titleCtrl.text.trim();
                  final subtitle = subtitleCtrl.text.trim();
                  final description = descriptionCtrl.text.trim();
                  final linkUrl = linkCtrl.text.trim();

                  if (isEdit) {
                    await _service.update(
                      id: slider?["id"] as int,
                      title: title,
                      subtitle: subtitle.isEmpty ? null : subtitle,
                      description: description.isEmpty ? null : description,
                      imageUrl: imageUrl,
                      linkUrl: linkUrl.isEmpty ? null : linkUrl,
                      sortOrder: sortOrder,
                      isActive: isActive,
                    );
                  } else {
                    await _service.add(
                      title: title,
                      subtitle: subtitle.isEmpty ? null : subtitle,
                      description: description.isEmpty ? null : description,
                      imageUrl: imageUrl,
                      linkUrl: linkUrl.isEmpty ? null : linkUrl,
                      sortOrder: sortOrder,
                      isActive: isActive,
                    );
                  }
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? "Slider güncellendi" : "Slider oluşturuldu")),
                    );
                  }
                } catch (e) {
                  await _showError(e.toString());
                }
              },
              child: Text(isEdit ? "Kaydet" : "Oluştur", style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Slider Sil"),
        content: const Text("Bu slider'ı silmek istiyor musunuz?"),
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
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Slider silindi")));
      }
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> slider, bool value) async {
    try {
      await _service.update(
        id: slider["id"] as int,
        title: (slider["title"] ?? "").toString(),
        subtitle: (slider["subtitle"] ?? "").toString().isEmpty ? null : slider["subtitle"].toString(),
        description: (slider["description"] ?? "").toString().isEmpty ? null : slider["description"].toString(),
        imageUrl: (slider["image_url"] ?? "").toString(),
        linkUrl: (slider["link_url"] ?? "").toString().isEmpty ? null : slider["link_url"].toString(),
        sortOrder: _parseSort(slider["sort_order"]),
        isActive: value,
      );
      await _loadData();
    } catch (e) {
      await _showError(e.toString());
    }
  }

  int _parseSort(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  Widget _buildCover(String url) {
    final normalized = UploadService.normalizeUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: safeImage(
        normalized,
        width: 90,
        height: 60,
        fit: BoxFit.cover,
        fallbackIcon: Icons.image_not_supported,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Slider Yönetimi",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Slider Ekle", style: TextStyle(color: Colors.white)),
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
            hintText: "Başlık veya link ara...",
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
            child: _loading
                ? const AdminLoadingIndicator()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (_filtered.isEmpty) {
                        return const Center(child: Text("Slider bulunamadı."));
                      }
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                            columns: const [
                              DataColumn(label: Text("Görsel")),
                              DataColumn(label: Text("Başlık")),
                              DataColumn(label: Text("Aktif")),
                              DataColumn(label: Text("Sıra")),
                              DataColumn(label: Text("Link")),
                              DataColumn(label: Text("Oluşturma")),
                              DataColumn(label: Text("İşlem")),
                            ],
                            rows: _filtered.map((s) {
                              final active = s["is_active"] == true;
                              return DataRow(
                                cells: [
                                  DataCell(_buildCover(s["image_url"] ?? "")),
                                  DataCell(Text(s["title"] ?? "")),
                                  DataCell(
                                    Switch(
                                      value: active,
                                      onChanged: (val) => _toggleActive(s, val),
                                    ),
                                  ),
                                  DataCell(Text(_parseSort(s["sort_order"]).toString())),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        (s["link_url"] ?? "-").toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_formatDateTime(s["created_at"]))),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showAddOrEditDialog(slider: s),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteItem(s["id"] as int),
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
}
