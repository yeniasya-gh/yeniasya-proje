import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/admin/admin_ek_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/safe_image.dart';
import '../../services/loading_manager.dart';
import 'admin_loading_indicator.dart';

class AdminEklerPage extends StatefulWidget {
  const AdminEklerPage({super.key});

  @override
  State<AdminEklerPage> createState() => _AdminEklerPageState();
}

class _AdminEklerPageState extends State<AdminEklerPage> {
  final _service = AdminEkService();
  final _uploadService = UploadService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false; // tek loading kontrolü: işlemler sırasında true yapılır
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _saving = true;
    });
    try {
      final list = await _service.getAll();
      setState(() {
        _items = list;
        _applyFilter(_searchCtrl.text);
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _saving = false;
        });
      }
    }
  }

  void _applyFilter(String value) {
    final q = value.toLowerCase();
    setState(() {
      _filtered = _items.where((e) {
        return (e["ad"] ?? "").toString().toLowerCase().contains(q) ||
            (e["aciklama"] ?? "").toString().toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final adCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    final fiyatCtrl = TextEditingController(text: "0");
    final pdfCtrl = TextEditingController();
    final imageCtrl = TextEditingController();

    Uint8List? pickedPdfBytes;
    String? pickedPdfName;
    Uint8List? pickedImageBytes;
    String? pickedImageName;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text("Yeni Ek"),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: adCtrl,
                    decoration: const InputDecoration(labelText: "Ek adı"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Zorunlu" : null,
                  ),
                  TextFormField(
                    controller: aciklamaCtrl,
                    decoration: const InputDecoration(labelText: "Açıklama"),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: fiyatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Fiyat (0 = ücretsiz)"),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Zorunlu";
                      return double.tryParse(v.replaceAll(",", ".")) == null ? "Geçerli sayı girin" : null;
                    },
                  ),
                  TextFormField(
                    controller: pdfCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await _pickPdf();
                      if (picked == null) return;
                      pickedPdfBytes = picked.bytes;
                      pickedPdfName = picked.name;
                      setSt(() => pdfCtrl.text = picked.name);
                    },
                    decoration: InputDecoration(
                      labelText: "PDF",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () async {
                          final picked = await _pickPdf();
                          if (picked == null) return;
                          pickedPdfBytes = picked.bytes;
                          pickedPdfName = picked.name;
                          setSt(() => pdfCtrl.text = picked.name);
                        },
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "PDF seçin" : null,
                  ),
                  TextFormField(
                    controller: imageCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await _pickImage();
                      if (picked == null) return;
                      pickedImageBytes = picked.bytes;
                      pickedImageName = picked.name;
                      setSt(() => imageCtrl.text = picked.name);
                    },
                    decoration: InputDecoration(
                      labelText: "Kapak Fotoğrafı (PNG/JPG/WEBP)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: () async {
                          final picked = await _pickImage();
                          if (picked == null) return;
                          pickedImageBytes = picked.bytes;
                          pickedImageName = picked.name;
                          setSt(() => imageCtrl.text = picked.name);
                        },
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "Fotoğraf seçin" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      if (pickedPdfBytes == null || pickedPdfName == null) {
                        _showSnack("PDF seçin");
                        return;
                      }
                      if (pickedImageBytes == null || pickedImageName == null) {
                        _showSnack("Fotoğraf seçin");
                        return;
                      }
                      final raw = fiyatCtrl.text.replaceAll(",", ".");
                      final fiyat = double.tryParse(raw) ?? 0;
                      if (fiyat < 0) {
                        _showSnack("Fiyat 0'dan küçük olamaz");
                        return;
                      }
                      Navigator.pop(ctx, {
                        "ad": adCtrl.text.trim(),
                        "aciklama": aciklamaCtrl.text.trim(),
                        "fiyat": fiyat,
                        "pdfBytes": pickedPdfBytes,
                        "pdfName": pickedPdfName,
                        "imageBytes": pickedImageBytes,
                        "imageName": pickedImageName,
                      });
                    },
              child: AnimatedBuilder(
                animation: LoadingManager.instance,
                builder: (_, __) {
                  if (_saving && !LoadingManager.instance.loading) {
                    return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return const Text("Kaydet");
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final ad = (result["ad"] ?? "").toString();
    final aciklama = (result["aciklama"] ?? "").toString();
    final fiyat = result["fiyat"] is num ? (result["fiyat"] as num).toDouble() : double.tryParse("${result["fiyat"]}") ?? 0;
    final bytes = result["pdfBytes"] as Uint8List?;
    final name = result["pdfName"]?.toString();
    final imageBytes = result["imageBytes"] as Uint8List?;
    final imageName = result["imageName"]?.toString();
    if (bytes == null || name == null) {
      _showSnack("PDF bulunamadı");
      return;
    }
    if (imageBytes == null || imageName == null) {
      _showSnack("Fotoğraf bulunamadı");
      return;
    }

    setState(() => _saving = true);
    try {
      final isFree = fiyat == 0;
      final photoUrl = await _uploadService.uploadPublic(
        type: UploadFileType.supplement,
        bytes: imageBytes,
        filename: imageName,
      );
      // PDF her zaman private yüklensin (ücretsiz olsa bile)
      final url = await _uploadService.uploadPrivate(
        type: UploadFileType.supplement,
        bytes: bytes,
        filename: name,
      );

      await _service.add(
        ad: ad,
        aciklama: aciklama.isEmpty ? null : aciklama,
        fiyat: fiyat,
        pdfUrl: UploadService.normalizeUrl(url),
        photoUrl: UploadService.normalizeUrl(photoUrl),
      );
      await _load();
      _showSnack("Ek oluşturuldu");
    } catch (e) {
      _showSnack(ErrorManager.parseGraphQLError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> ek) async {
    final formKey = GlobalKey<FormState>();
    final adCtrl = TextEditingController(text: ek["ad"]?.toString() ?? "");
    final aciklamaCtrl = TextEditingController(text: ek["aciklama"]?.toString() ?? "");
    final fiyatCtrl = TextEditingController(text: (ek["fiyat"] ?? 0).toString());
    final pdfCtrl = TextEditingController(text: _basename(ek["pdf_url"]?.toString() ?? ""));
    final imageCtrl = TextEditingController(text: _basename(ek["photo_url"]?.toString() ?? ""));

    Uint8List? pickedPdfBytes;
    String? pickedPdfName;
    Uint8List? pickedImageBytes;
    String? pickedImageName;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text("Ek Düzenle"),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: adCtrl,
                    decoration: const InputDecoration(labelText: "Ek adı"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Zorunlu" : null,
                  ),
                  TextFormField(
                    controller: aciklamaCtrl,
                    decoration: const InputDecoration(labelText: "Açıklama"),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: fiyatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Fiyat (0 = ücretsiz)"),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Zorunlu";
                      return double.tryParse(v.replaceAll(",", ".")) == null ? "Geçerli sayı girin" : null;
                    },
                  ),
                  TextFormField(
                    controller: pdfCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await _pickPdf();
                      if (picked == null) return;
                      pickedPdfBytes = picked.bytes;
                      pickedPdfName = picked.name;
                      setSt(() => pdfCtrl.text = picked.name);
                    },
                    decoration: InputDecoration(
                      labelText: "PDF (değiştirmek için tıkla)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () async {
                          final picked = await _pickPdf();
                          if (picked == null) return;
                          pickedPdfBytes = picked.bytes;
                          pickedPdfName = picked.name;
                          setSt(() => pdfCtrl.text = picked.name);
                        },
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "PDF seçin" : null,
                  ),
                  TextFormField(
                    controller: imageCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await _pickImage();
                      if (picked == null) return;
                      pickedImageBytes = picked.bytes;
                      pickedImageName = picked.name;
                      setSt(() => imageCtrl.text = picked.name);
                    },
                    decoration: InputDecoration(
                      labelText: "Kapak Fotoğrafı (değiştirmek için tıkla)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: () async {
                          final picked = await _pickImage();
                          if (picked == null) return;
                          pickedImageBytes = picked.bytes;
                          pickedImageName = picked.name;
                          setSt(() => imageCtrl.text = picked.name);
                        },
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "Fotoğraf seçin" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final raw = fiyatCtrl.text.replaceAll(",", ".");
                      final fiyat = double.tryParse(raw) ?? 0;
                      if (fiyat < 0) {
                        _showSnack("Fiyat 0'dan küçük olamaz");
                        return;
                      }
                      Navigator.pop(ctx, {
                        "ad": adCtrl.text.trim(),
                        "aciklama": aciklamaCtrl.text.trim(),
                        "fiyat": fiyat,
                        "pdfBytes": pickedPdfBytes,
                        "pdfName": pickedPdfName,
                        "imageBytes": pickedImageBytes,
                        "imageName": pickedImageName,
                        "pdfUrl": ek["pdf_url"]?.toString() ?? "",
                        "photoUrl": ek["photo_url"]?.toString() ?? "",
                        "id": ek["id"],
                      });
                    },
              child: AnimatedBuilder(
                animation: LoadingManager.instance,
                builder: (_, __) {
                  if (_saving && !LoadingManager.instance.loading) {
                    return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return const Text("Güncelle");
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final ad = (result["ad"] ?? "").toString();
    final aciklama = (result["aciklama"] ?? "").toString();
    final fiyat = result["fiyat"] is num ? (result["fiyat"] as num).toDouble() : double.tryParse("${result["fiyat"]}") ?? 0;
    final bytes = result["pdfBytes"] as Uint8List?;
    final name = result["pdfName"]?.toString();
    final imageBytes = result["imageBytes"] as Uint8List?;
    final imageName = result["imageName"]?.toString();
    var pdfUrl = result["pdfUrl"]?.toString() ?? "";
    var photoUrl = result["photoUrl"]?.toString() ?? "";

    setState(() => _saving = true);
    try {
      if (imageBytes != null && imageName != null) {
        photoUrl = await _uploadService.uploadPublic(
          type: UploadFileType.supplement,
          bytes: imageBytes,
          filename: imageName,
        );
      }
      if (bytes != null && name != null) {
        final isFree = fiyat == 0;
        pdfUrl = isFree
            ? await _uploadService.uploadPublic(
                type: UploadFileType.supplement,
                bytes: bytes,
                filename: name,
              )
            : await _uploadService.uploadPrivate(
                type: UploadFileType.supplement,
                bytes: bytes,
                filename: name,
              );
      }

      await _service.update(
        id: int.tryParse(result["id"].toString()) ?? 0,
        ad: ad,
        aciklama: aciklama.isEmpty ? null : aciklama,
        fiyat: fiyat,
        pdfUrl: UploadService.normalizeUrl(pdfUrl),
        photoUrl: UploadService.normalizeUrl(photoUrl),
      );
      await _load();
      _showSnack("Ek güncellendi");
    } catch (e) {
      _showSnack(ErrorManager.parseGraphQLError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEk(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ek Sil"),
        content: const Text("Bu eki silmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _service.delete(id);
      await _load();
      _showSnack("Ek silindi");
    } catch (e) {
      _showSnack(ErrorManager.parseGraphQLError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<PickedImageFile?> _pickPdf() async {
    try {
      return await AssetImagePicker.pickFile(allowedExtensions: const ["pdf"]);
    } catch (e) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("İşlem başarısız"),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam")),
          ],
        ),
      );
      return null;
    }
  }

  Future<PickedImageFile?> _pickImage() async {
    try {
      return await AssetImagePicker.pickFile(allowedExtensions: const ["png", "jpg", "jpeg", "webp"]);
    } catch (e) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("İşlem başarısız"),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam")),
          ],
        ),
      );
      return null;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildList() {
    if (_loading) {
      return const SizedBox();
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text("Henüz ek yok."));
    }
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final ek = _filtered[i];
        final isPublic = ek["is_public"] == true || (ek["fiyat"] ?? 0) == 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              _thumb(ek["photo_url"]?.toString()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ek["ad"] ?? "-").toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (ek["aciklama"] ?? "").toString().isEmpty ? "Açıklama yok" : (ek["aciklama"] ?? "").toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text("PDF: ${ek["pdf_url"] ?? "-"}",
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _chip(isPublic ? "Public" : "Private", isPublic ? Colors.green : Colors.red),
                  const SizedBox(height: 6),
                  Text(_formatPrice(ek["fiyat"]), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: "Düzenle",
                        onPressed: _saving ? null : () => _showEditDialog(ek),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        tooltip: "Sil",
                        onPressed: _saving
                            ? null
                            : () {
                                final id = ek["id"] is int ? ek["id"] as int : int.tryParse(ek["id"]?.toString() ?? "");
                                if (id == null) {
                                  _showSnack("Geçersiz ek ID");
                                  return;
                                }
                                _deleteEk(id);
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPrice(dynamic price) {
    final p = price is num ? price.toDouble() : double.tryParse(price?.toString() ?? "") ?? 0;
    return p == 0 ? "Ücretsiz" : "₺${p.toStringAsFixed(2)}";
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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
                const Text("Ekler", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Yeni Ek"),
                ),
              ],
            ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Ad veya açıklamada ara",
                border: OutlineInputBorder(),
              ),
              onChanged: _applyFilter,
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildList()),
          ],
        ),
        if (_saving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.08),
              child: const AdminLoadingIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _thumb(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        height: 60,
        color: Colors.grey.shade200,
        child: (url == null || url.isEmpty)
            ? const Icon(Icons.image_not_supported)
            : safeImage(
                url,
                fit: BoxFit.cover,
                fallbackIcon: Icons.image_not_supported,
              ),
      ),
    );
  }

  String _basename(String path) {
    if (path.isEmpty) return "";
    final parts = path.split("/");
    return parts.isNotEmpty ? parts.last : path;
  }
}
