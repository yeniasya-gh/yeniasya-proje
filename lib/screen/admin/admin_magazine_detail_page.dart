import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../services/admin/admin_review_service.dart';
import '../../services/loading_manager.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/safe_image.dart';
import 'admin_loading_indicator.dart';

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
  final AdminReviewService _reviewService = AdminReviewService();

  List<Map<String, dynamic>> _issues = [];
  bool _loading = true;
  bool _submitting = false;
  bool _loadingReviews = true;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  int _reviewCount = 0;
  final Set<int> _publicationBusyIssueIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadIssues();
    _loadReviews();
  }

  Future<void> _loadIssues() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getAdminIssues(widget.magazine["id"] as int);
      setState(() => _issues = list);
    } catch (e) {
      await _showError(e.toString());
    }
    setState(() => _loading = false);
  }

  bool _issueIsPublished(Map<String, dynamic> issue) =>
      issue["is_published"] != false;

  void _setIssuePublicationLocally(int id, bool isPublished) {
    _issues = _issues
        .map((issue) {
          if (issue["id"] != id) return issue;
          return {...issue, "is_published": isPublished};
        })
        .toList(growable: false);
  }

  Future<void> _toggleIssuePublication(
    Map<String, dynamic> issue,
    bool isPublished,
  ) async {
    final id = issue["id"] as int?;
    if (id == null || _publicationBusyIssueIds.contains(id)) return;

    setState(() => _publicationBusyIssueIds.add(id));
    try {
      await _service.setIssuePublicationStatus(
        id: id,
        isPublished: isPublished,
      );
      if (!mounted) return;
      setState(() => _setIssuePublicationLocally(id, isPublished));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPublished
                ? "Dergi sayısı yayına alındı."
                : "Dergi sayısı yayından kaldırıldı.",
          ),
        ),
      );
    } catch (e) {
      await _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _publicationBusyIssueIds.remove(id));
      } else {
        _publicationBusyIssueIds.remove(id);
      }
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final data = await _reviewService.getReviews(
        productType: "magazine",
        productId: widget.magazine["id"] as int,
      );
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data["reviews"] ?? []);
        _avgRating = (data["average"] as double?) ?? 0;
        _reviewCount = data["count"] is int
            ? data["count"] as int
            : int.tryParse(data["count"]?.toString() ?? "0") ?? 0;
      });
    } catch (e) {
      await _showError(e.toString());
    }
    setState(() => _loadingReviews = false);
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

  String _formatAsMoney(String raw) {
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

  List<int> _yearOptions({int? selectedYear}) {
    final now = DateTime.now().year;
    final years = <int>[for (int y = now + 1; y >= 2000; y--) y];
    if (selectedYear != null && !years.contains(selectedYear)) {
      years.add(selectedYear);
      years.sort((a, b) => b.compareTo(a));
    }
    return years;
  }

  int _issueYear(Map<String, dynamic> issue) {
    final raw = issue["added_at"]?.toString();
    final dt = raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
    return dt?.year ?? DateTime.now().year;
  }

  String _yearToAddedAt(int year) {
    final normalizedYear = year.clamp(2000, 9999);
    return "${normalizedYear.toString().padLeft(4, '0')}-01-01";
  }

  Future<void> _showAddIssueDialog() async {
    final formKey = GlobalKey<FormState>();
    final issueCtrl = TextEditingController();
    final fileCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nowYear = DateTime.now().year;
    int selectedYear = nowYear;

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
                    decoration: const InputDecoration(
                      labelText: "Sayı Numarası (1,2,3...)",
                    ),
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
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    decoration: const InputDecoration(labelText: "Yıl"),
                    items: _yearOptions(selectedYear: selectedYear)
                        .map(
                          (y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(() => selectedYear = value ?? nowYear);
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
                    validator: (v) => v == null || v.trim().isEmpty
                        ? "Bu alan zorunlu"
                        : null,
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
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final formatted = _formatAsMoney(value);
                      priceCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    },
                    decoration: const InputDecoration(
                      labelText: "Fiyat",
                      prefixText: "₺ ",
                    ),
                    validator: (v) {
                      final p = _parsePrice(v ?? "");
                      if (p == null) return "Geçerli bir fiyat girin";
                      if (p < 0) return "Fiyat negatif olamaz";
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Açıklama"),
                  ),
                  if (_submitting)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AnimatedBuilder(
                        animation: LoadingManager.instance,
                        builder: (_, __) {
                          if (LoadingManager.instance.loading)
                            return const SizedBox.shrink();
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
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
                      final price = _parsePrice(priceCtrl.text.trim());
                      if (price == null || price < 0) return;
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
                        if (pickedPhotoBytes != null &&
                            pickedPhotoName != null) {
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
                          price: price,
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          addedAt: _yearToAddedAt(selectedYear),
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
              child: const Text(
                "Kaydet",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditIssueDialog(Map<String, dynamic> issue) async {
    final formKey = GlobalKey<FormState>();
    final issueCtrl = TextEditingController(
      text: issue["issue_number"]?.toString() ?? "",
    );
    final fileCtrl = TextEditingController(text: issue["file_url"] ?? "");
    final photoCtrl = TextEditingController(text: issue["photo_url"] ?? "");
    final priceCtrl = TextEditingController(
      text: (issue["price"] ?? "").toString(),
    );
    final descCtrl = TextEditingController(
      text: (issue["description"] ?? "").toString(),
    );
    int selectedYear = _issueYear(issue);
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
                    decoration: const InputDecoration(
                      labelText: "Sayı Numarası",
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Zorunlu";
                      if (int.tryParse(v.trim()) == null)
                        return "Geçerli bir sayı girin";
                      return null;
                    },
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    decoration: const InputDecoration(labelText: "Yıl"),
                    items: _yearOptions(selectedYear: selectedYear)
                        .map(
                          (y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(
                        () => selectedYear = value ?? DateTime.now().year,
                      );
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
                    validator: (v) => v == null || v.trim().isEmpty
                        ? "Bu alan zorunlu"
                        : null,
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
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final formatted = _formatAsMoney(value);
                      priceCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    },
                    decoration: const InputDecoration(
                      labelText: "Fiyat",
                      prefixText: "₺ ",
                    ),
                    validator: (v) {
                      final p = _parsePrice(v ?? "");
                      if (p == null) return "Geçerli bir fiyat girin";
                      if (p < 0) return "Fiyat negatif olamaz";
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Açıklama"),
                  ),
                  if (submitting)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AnimatedBuilder(
                        animation: LoadingManager.instance,
                        builder: (_, __) {
                          if (LoadingManager.instance.loading)
                            return const SizedBox.shrink();
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
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
                      final price = _parsePrice(priceCtrl.text.trim());
                      if (price == null || price < 0) return;
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
                        if (pickedPhotoBytes != null &&
                            pickedPhotoName != null) {
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
                          price: price,
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          addedAt: _yearToAddedAt(selectedYear),
                        );
                        await _uploadService.cleanupReplacedFile(
                          previousUrl: issue["file_url"]?.toString(),
                          nextUrl: fileUrl,
                        );
                        await _uploadService.cleanupReplacedFile(
                          previousUrl: issue["photo_url"]?.toString(),
                          nextUrl: photoUrl,
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
              child: const Text(
                "Kaydet",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
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

  String _formatDate(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    final two = (int v) => v.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Seçildi: ${picked.name}")));
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

  Future<void> _pickPdf({
    required TextEditingController controller,
    required void Function(Uint8List bytes, String name) onPicked,
  }) async {
    try {
      final picked = await AssetImagePicker.pickFile(
        allowedExtensions: const ["pdf"],
      );
      if (picked == null) return;
      onPicked(picked.bytes, picked.name);
      controller.text = picked.name;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Seçildi: ${picked.name}")));
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
        child: SingleChildScrollView(
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
                    label: const Text(
                      "Yeni Sayı",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _showAddIssueDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
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
                    ? const AdminLoadingIndicator()
                    : _issues.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text("Henüz sayı eklenmemiş."),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _issues.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) {
                          final issue = _issues[i];
                          final issueYear = _issueYear(issue);
                          final issueId = issue["id"] as int?;
                          final isPublished = _issueIsPublished(issue);
                          final busy =
                              issueId != null &&
                              _publicationBusyIssueIds.contains(issueId);
                          return ListTile(
                            leading: _issueCover(issue["photo_url"]),
                            title: Text(
                              "${(magazine["name"] ?? "").toString()} - ${issue["issue_number"]}",
                            ),
                            subtitle: Text(
                              "Yıl: $issueYear • Eklendi: ${_formatDate(issue["added_at"])} • ${isPublished ? "Yayında" : "Kapalı"}",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch.adaptive(
                                  value: isPublished,
                                  onChanged: busy
                                      ? null
                                      : (value) => _toggleIssuePublication(
                                          issue,
                                          value,
                                        ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () => _showEditIssueDialog(issue),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteIssue(issue["id"] as int),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              _reviewsSection(),
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Yorumlar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_reviewCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "⭐ ${_avgRating.toStringAsFixed(1)} ($_reviewCount)",
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _loadingReviews
              ? const AdminLoadingIndicator(padding: EdgeInsets.all(16))
              : _reviews.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Bu dergi için yorum yok."),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final r = _reviews[i];
                    return ListTile(
                      title: Row(
                        children: [
                          Text(
                            "Kullanıcı #${r["user_id"] ?? "-"}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          _ratingStars((r["rating"] ?? 0) as int? ?? 0),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(r["comment"] ?? "-"),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(r["created_at"]),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _ratingStars(int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < value ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: safeImage(
        url,
        width: 70,
        height: 100,
        fit: BoxFit.cover,
        fallbackIcon: Icons.broken_image,
      ),
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
    final normalized = _normalizePeriod(period);
    final label = switch (normalized) {
      "1m" => "Aylık",
      "3m" => "3 Aylık",
      _ => "-",
    };

    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFFFEBEE),
      labelStyle: const TextStyle(
        color: Colors.red,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.zero,
    );
  }

  String? _normalizePeriod(dynamic period) {
    final normalized = period?.toString().toLowerCase();
    if (normalized == "6m") return "1m";
    if (normalized == "12m") return "3m";
    return normalized;
  }
}
