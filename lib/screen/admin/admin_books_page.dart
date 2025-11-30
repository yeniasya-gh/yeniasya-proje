import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/admin/admin_book_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/admin/admin_author_service.dart';
import '../../services/admin/admin_category_service.dart';
import '../../services/upload_service.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/safe_image.dart';

class AdminBooksPage extends StatefulWidget {
  const AdminBooksPage({super.key});

  @override
  State<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends State<AdminBooksPage> {
  final TextEditingController searchCtrl = TextEditingController();
  final AdminBookService _bookService = AdminBookService();
  final UploadService _uploadService = UploadService();

  List<Map<String, dynamic>> allBooks = [];
  List<Map<String, dynamic>> filteredBooks = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => isLoading = true);

    try {
      final books = await _bookService.getAllBooks();
      setState(() {
        allBooks = books;
        filteredBooks = books;
      });
    } catch (e) {
      await _showError(e.toString());
    }

    setState(() => isLoading = false);
  }

  void _filter(String text) {
    setState(() {
      filteredBooks = allBooks.where((b) {
        final q = text.toLowerCase();
        return (b["title"] ?? "").toString().toLowerCase().contains(q) ||
            (b["author"] ?? "").toString().toLowerCase().contains(q) ||
            (b["isbn"] ?? "").toString().toLowerCase().contains(q);
      }).toList();
    });
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

  // ❗ Hata popup
  Future<void> _showError(String rawError) {
    final parsed = ErrorManager.parseGraphQLError(
      rawError.replaceFirst("Exception: ", "").trim(),
    );

    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hata"),
        content: Text(parsed),
        actions: [
          TextButton(
            child: const Text("Tamam"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ❌ Kitap sil
  Future<void> _deleteBook(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kitap Sil"),
        content: const Text("Bu kitabı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final ok = await _bookService.deleteBook(id);
      if (ok) {
        await _loadBooks();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Kitap silindi")));
        }
      }
    } catch (e) {
      await _showError(e.toString());
    }
  }

  // 🔢 price parse helper
  double? _parsePrice(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(",", "."));
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

  // ➕ Kitap ekleme popup
  void _showAddBookDialog({Map<String, dynamic>? initial}) async {
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(text: initial?["title"] ?? "");
    final isbnCtrl = TextEditingController(text: initial?["isbn"] ?? "");
    final coverCtrl = TextEditingController(text: initial?["cover"] ?? "");
    final bookFileCtrl = TextEditingController(text: initial?["book_url"] ?? "");
    final priceCtrl = TextEditingController(text: initial?["price_text"] ?? "");
    final discountCtrl = TextEditingController(text: initial?["discount_text"] ?? "");
    final descCtrl = TextEditingController(text: initial?["description"] ?? "");
    final minDescCtrl = TextEditingController(text: initial?["min_description"] ?? "");

    // Fetch authors and categories
    final authors = await AdminAuthorService().getAllAuthors();
    final categories = await AdminCategoryService().getAllCategories();
    int? selectedAuthorId = initial?["author_id"] as int?;
    int? selectedCategoryId = initial?["category_id"] as int?;

    Uint8List? pickedCoverBytes;
    String? pickedCoverName;
    Uint8List? pickedPdfBytes;
    String? pickedPdfName;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Yeni Kitap Ekle"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: "Kitap Adı"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Kitap adı zorunlu" : null,
                    ),
                    TextFormField(
                      controller: isbnCtrl,
                      decoration: const InputDecoration(labelText: "ISBN"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "ISBN zorunlu" : null,
                    ),
                    DropdownButtonFormField<int>(
                      value: selectedAuthorId,
                      decoration: const InputDecoration(labelText: "Yazar"),
                      items: authors
                          .map((a) => DropdownMenuItem(
                                value: a["id"] as int,
                                child: Text(a["name"]),
                              ))
                          .toList(),
                      onChanged: (v) => selectedAuthorId = v,
                    ),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: "Kategori"),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c["id"] as int,
                                child: Text(c["name"]),
                              ))
                          .toList(),
                      onChanged: (v) => selectedCategoryId = v,
                    ),
                    TextFormField(
                      controller: coverCtrl,
                      readOnly: true,
                      onTap: () => _pickImage(
                        controller: coverCtrl,
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
                            controller: coverCtrl,
                            onPicked: (bytes, name) {
                              pickedCoverBytes = bytes;
                              pickedCoverName = name;
                            },
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: bookFileCtrl,
                      readOnly: true,
                      onTap: () => _pickPdf(
                        controller: bookFileCtrl,
                        onPicked: (bytes, name) {
                          pickedPdfBytes = bytes;
                          pickedPdfName = name;
                        },
                      ),
                      decoration: InputDecoration(
                        labelText: "Kitap PDF (özel erişim)",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.upload_file),
                          onPressed: () => _pickPdf(
                            controller: bookFileCtrl,
                            onPicked: (bytes, name) {
                              pickedPdfBytes = bytes;
                              pickedPdfName = name;
                            },
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? "PDF zorunlu" : null,
                    ),
                    TextFormField(
                      controller: priceCtrl,
                      onChanged: (value) {
                        final formatted = formatAsMoney(value);

                        priceCtrl.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Satış Fiyatı (zorunlu)",
                        prefixText: "₺ ",
                      ),
                      validator: (v) {
                        final price = _parsePrice(v ?? "");
                        if (price == null) return "Geçerli bir fiyat girin";
                        if (price <= 0) return "Fiyat 0'dan büyük olmalı";
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: discountCtrl,
                      onChanged: (value) {
                        final formatted = formatAsMoney(value);

                        discountCtrl.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Kampanya Fiyatı (opsiyonel)",
                        prefixText: "₺ ",
                      ),
                    ),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: "Açıklama (opsiyonel)",
                  ),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: minDescCtrl,
                  decoration: const InputDecoration(
                    labelText: "Kısa Açıklama (opsiyonel)",
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
          ),
          actions: [
            TextButton(
              child: const Text("Kapat"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                "Kaydet",
                style: TextStyle(color: Colors.white),
              ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final payload = {
                "title": titleCtrl.text.trim(),
                "isbn": isbnCtrl.text.trim(),
                "cover": coverCtrl.text.trim(),
                "book_url": bookFileCtrl.text.trim(),
                "price_text": priceCtrl.text,
                "discount_text": discountCtrl.text,
                "description": descCtrl.text.trim(),
                "min_description": minDescCtrl.text.trim(),
                "author_id": selectedAuthorId,
                "category_id": selectedCategoryId,
              };

              final price =
                  _parsePrice((payload["price_text"] as String?) ?? "")!;
              final discount =
                  _parsePrice((payload["discount_text"] as String?) ?? "");

              Navigator.pop(context);

              try {
                String? coverUrl;
                if (pickedCoverBytes != null && pickedCoverName != null) {
                  coverUrl = await _uploadService.uploadPublic(
                    type: UploadFileType.book,
                    bytes: pickedCoverBytes!,
                    filename: pickedCoverName!,
                  );
                } else if ((payload["cover"] as String).isNotEmpty) {
                  coverUrl = payload["cover"] as String;
                }

                String? bookUrl = (payload["book_url"] as String).isNotEmpty
                    ? payload["book_url"] as String
                    : null;
                if (pickedPdfBytes != null && pickedPdfName != null) {
                  bookUrl = await _uploadService.uploadPrivate(
                    type: UploadFileType.book,
                    bytes: pickedPdfBytes!,
                    filename: pickedPdfName!,
                  );
                }

                await _bookService.addBook(
                  title: payload["title"] as String,
                  isbn: payload["isbn"] as String,
                  price: price,
                  coverUrl: coverUrl,
                  bookUrl: bookUrl,
                  discountPrice: discount,
                  categoryId: payload["category_id"] as int?,
                  authorId: payload["author_id"] as int?,
                  description: (payload["description"] as String).isEmpty
                      ? null
                      : payload["description"] as String,
                  minDescription: (payload["min_description"] as String).isEmpty
                      ? null
                      : payload["min_description"] as String,
                );

                await _loadBooks();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Kitap eklendi")),
                  );
                }
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _showAddBookDialog(initial: payload),
                  );
                }
              }
            },
          ),
          ],
        );
      },
    );
  }

  // ✏️ Kitap düzenleme popup
  void _showEditBookDialog(Map<String, dynamic> book) async {
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(text: book["title"] ?? "");
    final isbnCtrl = TextEditingController(text: book["isbn"] ?? "");
    final coverCtrl = TextEditingController(text: book["cover_url"] ?? "");
    final bookFileCtrl = TextEditingController(text: book["book_url"] ?? "");
    final priceCtrl = TextEditingController(
      text: (book["price"] ?? "").toString(),
    );
    final discountCtrl = TextEditingController(
      text: (book["discount_price"] ?? "").toString(),
    );
    final descCtrl = TextEditingController(
      text: (book["description"] ?? "").toString(),
    );
    final minDescCtrl = TextEditingController(
      text: (book["min_description"] ?? "").toString(),
    );

    // Fetch authors and categories
    final authors = await AdminAuthorService().getAllAuthors();
    final categories = await AdminCategoryService().getAllCategories();
    int? selectedAuthorId = book["author_id"];
    int? selectedCategoryId = book["category_id"];

    Uint8List? pickedCoverBytes;
    String? pickedCoverName;
    Uint8List? pickedPdfBytes;
    String? pickedPdfName;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Kitap Düzenle"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: "Kitap Adı"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Kitap adı zorunlu" : null,
                    ),
                    TextFormField(
                      controller: isbnCtrl,
                      decoration: const InputDecoration(labelText: "ISBN"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "ISBN zorunlu" : null,
                    ),
                    DropdownButtonFormField<int>(
                      value: selectedAuthorId,
                      decoration: const InputDecoration(labelText: "Yazar"),
                      items: authors
                          .map((a) => DropdownMenuItem(
                                value: a["id"] as int,
                                child: Text(a["name"]),
                              ))
                          .toList(),
                      onChanged: (v) => selectedAuthorId = v,
                    ),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: "Kategori"),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c["id"] as int,
                                child: Text(c["name"]),
                              ))
                          .toList(),
                      onChanged: (v) => selectedCategoryId = v,
                    ),
                    TextFormField(
                      controller: coverCtrl,
                      readOnly: true,
                      onTap: () => _pickImage(
                        controller: coverCtrl,
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
                            controller: coverCtrl,
                            onPicked: (bytes, name) {
                              pickedCoverBytes = bytes;
                              pickedCoverName = name;
                            },
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: bookFileCtrl,
                      readOnly: true,
                      onTap: () => _pickPdf(
                        controller: bookFileCtrl,
                        onPicked: (bytes, name) {
                          pickedPdfBytes = bytes;
                          pickedPdfName = name;
                        },
                      ),
                      decoration: InputDecoration(
                        labelText: "Kitap PDF (özel erişim)",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.upload_file),
                          onPressed: () => _pickPdf(
                            controller: bookFileCtrl,
                            onPicked: (bytes, name) {
                              pickedPdfBytes = bytes;
                              pickedPdfName = name;
                            },
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? "PDF zorunlu" : null,
                    ),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Satış Fiyatı (zorunlu)",
                        prefixText: "₺ ",
                      ),
                      validator: (v) {
                        final price = _parsePrice(v ?? "");
                        if (price == null) return "Geçerli bir fiyat girin";
                        if (price <= 0) return "Fiyat 0'dan büyük olmalı";
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Kampanya Fiyatı (opsiyonel)",
                        prefixText: "₺ ",
                      ),
                    ),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: "Açıklama (opsiyonel)",
                  ),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: minDescCtrl,
                  decoration: const InputDecoration(
                    labelText: "Kısa Açıklama (opsiyonel)",
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
          ),
          actions: [
            TextButton(
              child: const Text("Kapat"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final payload = {
                "id": book["id"],
                "title": titleCtrl.text.trim(),
                "isbn": isbnCtrl.text.trim(),
                "cover": coverCtrl.text.trim(),
                "book_url": bookFileCtrl.text.trim(),
                "price_text": priceCtrl.text,
                "discount_text": discountCtrl.text,
                "description": descCtrl.text.trim(),
                "min_description": minDescCtrl.text.trim(),
                "author_id": selectedAuthorId,
                "category_id": selectedCategoryId,
              };

              final price =
                  _parsePrice((payload["price_text"] as String?) ?? "")!;
              final discount =
                  _parsePrice((payload["discount_text"] as String?) ?? "");

              Navigator.pop(context);

              try {
                String? coverUrl;
                if (pickedCoverBytes != null && pickedCoverName != null) {
                  coverUrl = await _uploadService.uploadPublic(
                    type: UploadFileType.book,
                    bytes: pickedCoverBytes!,
                    filename: pickedCoverName!,
                  );
                } else if ((payload["cover"] as String).isNotEmpty) {
                  coverUrl = payload["cover"] as String;
                }

                String? bookUrl = (payload["book_url"] as String).isNotEmpty
                    ? payload["book_url"] as String
                    : null;
                if (pickedPdfBytes != null && pickedPdfName != null) {
                  bookUrl = await _uploadService.uploadPrivate(
                    type: UploadFileType.book,
                    bytes: pickedPdfBytes!,
                    filename: pickedPdfName!,
                  );
                }

                await _bookService.updateBook(
                  id: payload["id"] as int,
                  title: payload["title"] as String,
                  isbn: payload["isbn"] as String,
                  price: price,
                  coverUrl: coverUrl,
                  bookUrl: bookUrl,
                  discountPrice: discount,
                  categoryId: payload["category_id"] as int?,
                  authorId: payload["author_id"] as int?,
                  description: (payload["description"] as String).isEmpty
                      ? null
                      : payload["description"] as String,
                  minDescription: (payload["min_description"] as String).isEmpty
                      ? null
                      : payload["min_description"] as String,
                );

                await _loadBooks();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Kitap güncellendi")),
                  );
                }
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _showEditBookDialog(payload),
                  );
                }
              }
            },
          ),
          ],
        );
      },
    );
  }

  Widget _buildCoverCell(String? url) {
    if (url == null || url.isEmpty) {
      return const SizedBox(
        width: 40,
        height: 60,
        child: ColoredBox(
          color: Color(0xFFE0E0E0),
          child: Icon(Icons.book_outlined, size: 24),
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ÜST BAR
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Kitap Yönetimi",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Kitap Ekle",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _showAddBookDialog,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Arama
        TextField(
          controller: searchCtrl,
          onChanged: _filter,
          decoration: InputDecoration(
            hintText: "Kitap, yazar veya ISBN ara...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 20),

        // TABLO
        // TABLO
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
            child: isLoading
                ? const SizedBox()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  Colors.grey.shade100,
                                ),
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text("Kapak")),
                                  DataColumn(label: Text("Başlık")),
                                  DataColumn(label: Text("Yazar")),
                                  DataColumn(label: Text("Kategori")),
                                  DataColumn(label: Text("Fiyat")),
                                  DataColumn(label: Text("Kampanya Fiyatı")),
                                  DataColumn(label: Text("ISBN")),
                                  DataColumn(label: Text("İşlem")),
                                ],
                                rows: filteredBooks.map((b) {
                                  return DataRow(
                                    cells: [
                                      DataCell(_buildCoverCell(b["cover_url"])),
                                      DataCell(Text(b["title"] ?? "")),
                                      DataCell(
                                          Text(b["author_rel"]?["name"] ?? "-")),
                                      DataCell(
                                          Text(b["category_rel"]?["name"] ?? "-")),
                                      DataCell(Text(_formatPrice(b["price"]))),
                                      DataCell(
                                        Text(_formatPrice(b["discount_price"])),
                                      ),
                                      DataCell(Text(b["isbn"] ?? "-")),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () =>
                                                  _showEditBookDialog(b),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  _deleteBook(b["id"]),
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
