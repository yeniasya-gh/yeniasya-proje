import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/admin/admin_newspaper_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/asset_image_picker.dart';

class AdminNewspapersPage extends StatefulWidget {
  const AdminNewspapersPage({super.key});

  @override
  State<AdminNewspapersPage> createState() => _AdminNewspapersPageState();
}

class _AdminNewspapersPageState extends State<AdminNewspapersPage> {
  final AdminNewspaperService _service = AdminNewspaperService();
  final TextEditingController _searchCtrl = TextEditingController();
  final UploadService _uploadService = UploadService();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final list = await _service.getAll();
      setState(() {
        _all = list;
        _filtered = list;
      });
    } catch (e) {
      await _showError(e.toString());
    }
  }

  void _filter(String value) {
    final q = value.toLowerCase();
    setState(() {
      _filtered = _all.where((n) {
        return (n["publish_date"] ?? "").toString().toLowerCase().contains(q) ||
            (n["file_url"] ?? "").toString().toLowerCase().contains(q);
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

  Future<void> _showAddOrEditDialog({Map<String, dynamic>? newspaper}) async {
    final isEdit = newspaper != null;
    final formKey = GlobalKey<FormState>();

    final imageCtrl = TextEditingController(text: newspaper?["image_url"] ?? "");
    final dateCtrl = TextEditingController(text: newspaper?["publish_date"] ?? "");
    final fileCtrl = TextEditingController(text: newspaper?["file_url"] ?? "");

    Uint8List? pickedImageBytes;
    String? pickedImageName;
    Uint8List? pickedPdfBytes;
    String? pickedPdfName;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Gazete Düzenle" : "Yeni Gazete"),
        content: SizedBox(
          width: 420,
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
                    },
                  ),
                  decoration: InputDecoration(
                    labelText: "Kapak Görseli (PNG/JPG/WEBP)",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: () => _pickImage(
                        imageCtrl,
                        onPicked: (bytes, name) {
                          pickedImageBytes = bytes;
                          pickedImageName = name;
                        },
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Zorunlu" : null,
                ),
                TextFormField(
                  controller: dateCtrl,
                  readOnly: true,
                  onTap: () async {
                    final now = DateTime.now();
                    final initial = DateTime.tryParse(dateCtrl.text) ?? now;
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) {
                      final formatted =
                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      dateCtrl.text = formatted;
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: "Yayın Tarihi",
                    suffixIcon: Icon(Icons.date_range),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Zorunlu" : null,
                ),
                TextFormField(
                  controller: fileCtrl,
                  readOnly: true,
                  onTap: () => _pickPdf(
                    fileCtrl,
                    onPicked: (bytes, name) {
                      pickedPdfBytes = bytes;
                      pickedPdfName = name;
                    },
                  ),
                  decoration: InputDecoration(
                    labelText: "Gazete PDF (özel erişim)",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: () => _pickPdf(
                        fileCtrl,
                        onPicked: (bytes, name) {
                          pickedPdfBytes = bytes;
                          pickedPdfName = name;
                        },
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Zorunlu" : null,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final payload = {
                "id": newspaper?["id"],
                "image_url": imageCtrl.text.trim(),
                "publish_date": dateCtrl.text.trim(),
                "file_url": fileCtrl.text.trim(),
              };

              Navigator.pop(context);

              try {
                String imageUrl = payload["image_url"] as String;
                if (pickedImageBytes != null && pickedImageName != null) {
                  imageUrl = await _uploadService.uploadPublic(
                    type: UploadFileType.newspaper,
                    bytes: pickedImageBytes!,
                    filename: pickedImageName!,
                  );
                }

                String fileUrl = payload["file_url"] as String;
                if (pickedPdfBytes != null && pickedPdfName != null) {
                  fileUrl = await _uploadService.uploadPrivate(
                    type: UploadFileType.newspaper,
                    bytes: pickedPdfBytes!,
                    filename: pickedPdfName!,
                  );
                }

                if (isEdit) {
                  await _service.update(
                    id: payload["id"] as int,
                    imageUrl: imageUrl,
                    fileUrl: fileUrl,
                    publishDate: payload["publish_date"] as String,
                  );
                } else {
                  await _service.add(
                    imageUrl: imageUrl,
                    fileUrl: fileUrl,
                    publishDate: payload["publish_date"] as String,
                  );
                }
                await _loadData();
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _showAddOrEditDialog(newspaper: payload),
                  );
                }
              }
            },
            child: Text(isEdit ? "Kaydet" : "Oluştur",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Gazete Sil"),
        content: const Text("Bu gazeteyi silmek istiyor musunuz?"),
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
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Widget _buildCover(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: _imageWidget(url),
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

  Future<void> _pickPdf(
    TextEditingController controller, {
    required void Function(Uint8List bytes, String name) onPicked,
  }) async {
    try {
      final picked = await AssetImagePicker.pickFile(allowedExtensions: const ["pdf"]);
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

  Widget _imageWidget(String url) {
    final normalized = UploadService.normalizeUrl(url);
    final isNetwork =
        normalized.startsWith("http://") || normalized.startsWith("https://");

    if (url.isEmpty) {
      return const SizedBox(
        width: 60,
        height: 70,
        child: ColoredBox(
          color: Color(0xFFE0E0E0),
          child: Icon(Icons.image_not_supported, size: 22),
        ),
      );
    }

    final fallback = const SizedBox(
      width: 60,
      height: 70,
      child: ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Icon(Icons.broken_image, size: 22),
      ),
    );

    return isNetwork
        ? Image.network(
            normalized,
            width: 60,
            height: 70,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.asset(
            normalized,
            width: 60,
            height: 70,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
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
              "Gazeteler",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Gazete Ekle", style: TextStyle(color: Colors.white)),
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
            hintText: "Tarih veya dosya ara...",
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
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            headingRowColor:
                                MaterialStateProperty.all(Colors.grey.shade100),
                            columns: const [
                              DataColumn(label: Text("Kapak")),
                              DataColumn(label: Text("Tarih")),
                              DataColumn(label: Text("Dosya")),
                              DataColumn(label: Text("Oluşturma")),
                              DataColumn(label: Text("İşlem")),
                            ],
                            rows: _filtered.map((n) {
                              return DataRow(
                                cells: [
                                  DataCell(_buildCover(n["image_url"] ?? "")),
                                  DataCell(Text(n["publish_date"] ?? "")),
                                  DataCell(Text(n["file_url"] ?? "")),
                                  DataCell(Text(_formatDateTime(n["created_at"]))),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showAddOrEditDialog(newspaper: n),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteItem(n["id"] as int),
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
    Uint8List? pickedImageBytes;
    String? pickedImageName;
