import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/safe_image.dart';
import '../../services/upload_service.dart';

class AdminMagazineDetailPage extends StatefulWidget {
  final Map<String, dynamic> magazine;

  const AdminMagazineDetailPage({super.key, required this.magazine});

  @override
  State<AdminMagazineDetailPage> createState() =>
      _AdminMagazineDetailPageState();
}

class _AdminMagazineDetailPageState extends State<AdminMagazineDetailPage> {
  final AdminMagazineService _service = AdminMagazineService();
  final UploadService _uploadService = UploadService();

  List<Map<String, dynamic>> _issues = [];
  bool _loading = true;
  bool _submitting = false;

  String _formatPrice(dynamic value) {
    if (value == null) return "-";
    try {
      final d = double.parse(value.toString());
      return "₺${d.toStringAsFixed(2)}";
    } catch (_) {
      return value.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getIssues(widget.magazine["id"] as int);
      setState(() => _issues = list);
    } catch (e) {
      await _showError(e.toString());
    }
    setState(() => _loading = false);
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

  Future<void> _showAddIssueDialog() async {
    final formKey = GlobalKey<FormState>();
    final issueCtrl = TextEditingController();
    final fileCtrl = TextEditingController();
    final saleCtrl = TextEditingController();
    final campaignCtrl = TextEditingController();
    final photoCtrl = TextEditingController();

    Uint8List? pickedPdfBytes;
    String? pickedPdfName;
    Uint8List? pickedPhotoBytes;
    String? pickedPhotoName;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Yeni Sayı Ekle"),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: issueCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "Sayı Numarası (1,2,3...)"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Bu alan zorunlu";
                      }
                      if (int.tryParse(v.trim()) == null) {
                        return "Geçerli bir sayı girin";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: fileCtrl,
                    readOnly: true,
                    onTap: () => _pickPdf(
                      controller: fileCtrl,
                      onPicked: (bytes, name) {
                        pickedPdfBytes = bytes;
                        pickedPdfName = name;
                      },
                    ),
                    decoration: InputDecoration(
                      labelText: "Sayı PDF (özel erişim)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => _pickPdf(
                          controller: fileCtrl,
                          onPicked: (bytes, name) {
                            pickedPdfBytes = bytes;
                            pickedPdfName = name;
                          },
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Bu alan zorunlu" : null,
                  ),
                  TextFormField(
                    controller: photoCtrl,
                    readOnly: true,
                    onTap: () => _pickImage(
                      controller: photoCtrl,
                      onPicked: (bytes, name) {
                        pickedPhotoBytes = bytes;
                        pickedPhotoName = name;
                      },
                    ),
                    decoration: InputDecoration(
                      labelText: "Kapak Fotoğrafı (public)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => _pickImage(
                          controller: photoCtrl,
                          onPicked: (bytes, name) {
                            pickedPhotoBytes = bytes;
                            pickedPhotoName = name;
                          },
                        ),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: saleCtrl,
                    onChanged: (value) {
                      final formatted = formatAsMoney(value);
                      saleCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    },
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Satış Fiyatı (zorunlu)"),
                    validator: (v) {
                      final price = _parsePrice(v ?? "");
                      if (price == null || price <= 0) {
                        return "Geçerli bir fiyat girin";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: campaignCtrl,
                    onChanged: (value) {
                      final formatted = formatAsMoney(value);
                      campaignCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    },
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Kampanya Fiyatı (opsiyonel)"),
                  ),
                  if (_submitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text("Kapat"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => _submitting = true);
                      setStateDialog(() {});

                      final issueNumber = int.parse(issueCtrl.text.trim());
                      final salePrice = _parsePrice(saleCtrl.text) ?? 0;
                      final campaignPrice = _parsePrice(campaignCtrl.text);

                      try {
                        String fileUrl = fileCtrl.text.trim();
                        if (pickedPdfBytes != null && pickedPdfName != null) {
                          fileUrl = await _uploadService.uploadPrivate(
                            type: UploadFileType.magazine,
                            bytes: pickedPdfBytes!,
                            filename: pickedPdfName!,
                          );
                        }

                        String? photoUrl = photoCtrl.text.trim().isEmpty
                            ? null
                            : photoCtrl.text.trim();
                        if (pickedPhotoBytes != null && pickedPhotoName != null) {
                          photoUrl = await _uploadService.uploadPublic(
                            type: UploadFileType.magazine,
                            bytes: pickedPhotoBytes!,
                            filename: pickedPhotoName!,
                          );
                        }

                        await _service.addIssue(
                          magazineId: widget.magazine["id"] as int,
                          issueNumber: issueNumber,
                          fileUrl: fileUrl,
                          photoUrl: photoUrl,
                          salePrice: salePrice,
                          campaignPrice: campaignPrice,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _loadIssues();
                      } catch (e) {
                        await _showError(e.toString());
                      } finally {
                        setState(() => _submitting = false);
                        setStateDialog(() {});
                      }
                    },
              child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditIssueDialog(Map<String, dynamic> issue) async {
    final formKey = GlobalKey<FormState>();
    final issueCtrl = TextEditingController(text: issue["issue_number"]?.toString() ?? "");
    final fileCtrl = TextEditingController(text: issue["file_url"] ?? "");
    final photoCtrl = TextEditingController(text: issue["photo_url"] ?? "");
    final saleCtrl = TextEditingController(
      text: issue["sale_price"]?.toString() ?? "",
    );
    final campaignCtrl = TextEditingController(
      text: issue["campaign_price"]?.toString() ?? "",
    );

    Uint8List? pickedPdfBytes;
    String? pickedPdfName;
    Uint8List? pickedPhotoBytes;
    String? pickedPhotoName;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Sayıyı Düzenle"),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: issueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Sayı Numarası"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Zorunlu";
                      if (int.tryParse(v.trim()) == null) return "Geçerli bir sayı girin";
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: fileCtrl,
                    readOnly: true,
                    onTap: () => _pickPdf(
                      controller: fileCtrl,
                      onPicked: (bytes, name) {
                        pickedPdfBytes = bytes;
                        pickedPdfName = name;
                      },
                    ),
                    decoration: InputDecoration(
                      labelText: "Sayı PDF (özel erişim)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => _pickPdf(
                          controller: fileCtrl,
                          onPicked: (bytes, name) {
                            pickedPdfBytes = bytes;
                            pickedPdfName = name;
                          },
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Bu alan zorunlu" : null,
                  ),
                  TextFormField(
                    controller: photoCtrl,
                    readOnly: true,
                    onTap: () => _pickImage(
                      controller: photoCtrl,
                      onPicked: (bytes, name) {
                        pickedPhotoBytes = bytes;
                        pickedPhotoName = name;
                      },
                    ),
                    decoration: InputDecoration(
                      labelText: "Kapak Fotoğrafı (public)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => _pickImage(
                          controller: photoCtrl,
                          onPicked: (bytes, name) {
                            pickedPhotoBytes = bytes;
                            pickedPhotoName = name;
                          },
                        ),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: saleCtrl,
                    onChanged: (value) {
                      final formatted = formatAsMoney(value);
                      saleCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    },
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Satış Fiyatı (zorunlu)"),
                    validator: (v) {
                      final price = _parsePrice(v ?? "");
                      if (price == null || price <= 0) return "Geçerli bir fiyat girin";
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: campaignCtrl,
                    onChanged: (value) {
                      final formatted = formatAsMoney(value);
                      campaignCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    },
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: "Kampanya Fiyatı (opsiyonel)"),
                  ),
                  if (submitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(context),
              child: const Text("Kapat"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => submitting = true);

                      final issueNumber = int.parse(issueCtrl.text.trim());
                      final salePrice = _parsePrice(saleCtrl.text) ?? 0;
                      final campaignPrice = _parsePrice(campaignCtrl.text);

                      try {
                        String fileUrl = fileCtrl.text.trim();
                        if (pickedPdfBytes != null && pickedPdfName != null) {
                          fileUrl = await _uploadService.uploadPrivate(
                            type: UploadFileType.magazine,
                            bytes: pickedPdfBytes!,
                            filename: pickedPdfName!,
                          );
                        }

                        String? photoUrl = photoCtrl.text.trim().isEmpty
                            ? null
                            : photoCtrl.text.trim();
                        if (pickedPhotoBytes != null && pickedPhotoName != null) {
                          photoUrl = await _uploadService.uploadPublic(
                            type: UploadFileType.magazine,
                            bytes: pickedPhotoBytes!,
                            filename: pickedPhotoName!,
                          );
                        }

                        await _service.updateIssue(
                          id: issue["id"] as int,
                          issueNumber: issueNumber,
                          fileUrl: fileUrl,
                          photoUrl: photoUrl,
                          salePrice: salePrice,
                          campaignPrice: campaignPrice,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _loadIssues();
                      } catch (e) {
                        await _showError(e.toString());
                      } finally {
                        setStateDialog(() => submitting = false);
                      }
                    },
              child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  double? _parsePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
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

  Future<void> _pickImage({
    required TextEditingController controller,
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

  Future<void> _pickPdf({
    required TextEditingController controller,
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

  Future<void> _deleteIssue(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sayı Sil"),
        content: const Text("Bu dergi sayısını silmek istiyor musunuz?"),
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
      await _service.deleteIssue(id);
      await _loadIssues();
    } catch (e) {
      await _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final magazine = widget.magazine;

    return Scaffold(
      appBar: AppBar(
        title: Text(magazine["name"] ?? "Dergi Detay"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(magazine),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Dergi Sayıları",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Yeni Sayı", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _showAddIssueDialog,
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
                      ? const Center(child: CircularProgressIndicator())
                      : _issues.isEmpty
                          ? const Center(child: Text("Henüz sayı eklenmemiş."))
                          : ListView.separated(
                              itemCount: _issues.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (_, i) {
                                final issue = _issues[i];
                                return ListTile(
                                  leading: _issueCover(issue["photo_url"]),
                                  title: Text(
                                      "${(magazine["name"] ?? "").toString()} - ${issue["issue_number"]}"),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Eklendi: ${_formatDateTime(issue["added_at"])}",
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            "Satış: ${_formatPrice(issue["sale_price"])}",
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            "Kampanya: ${_formatPrice(issue["campaign_price"])}",
                                            style: const TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                        onPressed: () => _showEditIssueDialog(issue),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteIssue(issue["id"] as int),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> magazine) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverCell(magazine["cover_image_url"]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  magazine["name"] ?? "",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  magazine["category"] ?? "",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPeriodChip(magazine["period"]),
                    const SizedBox(width: 12),
                    Text(
                      "Oluşturma: ${_formatDateTime(magazine["created_at"])}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Satış: ${_formatPrice(magazine["sale_price"])}",
                      style: const TextStyle(color: Colors.black87),
                    ),
                    if (magazine["campaign_price"] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          "Kampanya: ${_formatPrice(magazine["campaign_price"])}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCoverCell(String? url) {
    if (url == null || url.isEmpty) {
      return const SizedBox(
        width: 70,
        height: 100,
        child: ColoredBox(
          color: Color(0xFFE0E0E0),
          child: Icon(Icons.menu_book_outlined, size: 32),
        ),
      );
    }

    final normalized = UploadService.normalizeUrl(url);
    final isNetwork =
        normalized.startsWith("http://") || normalized.startsWith("https://");

    final fallback = const SizedBox(
      width: 70,
      height: 100,
      child: ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Icon(Icons.broken_image, size: 26),
      ),
    );

    final imageWidget = isNetwork
        ? Image.network(
            normalized,
            width: 70,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.asset(
            normalized,
            width: 70,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageWidget,
    );
  }

  Widget _issueCover(String? url) {
    final normalized = UploadService.normalizeUrl(url ?? "");
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: safeImage(
          normalized,
          width: 56,
          height: 56,
          fallbackIcon: Icons.broken_image,
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String? period) {
    final label = switch (period) {
      "monthly" => "Aylık",
      "three_months" => "3 Aylık",
      "six_months" => "6 Aylık",
      _ => "-",
    };

    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFFFEBEE),
      labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      padding: EdgeInsets.zero,
    );
  }
}
