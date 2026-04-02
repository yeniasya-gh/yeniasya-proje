import 'package:flutter/material.dart';

import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_ek_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/home_showcase_service.dart';
import 'admin_loading_indicator.dart';

class AdminHomeShowcasePage extends StatefulWidget {
  const AdminHomeShowcasePage({super.key});

  @override
  State<AdminHomeShowcasePage> createState() => _AdminHomeShowcasePageState();
}

class _AdminHomeShowcasePageState extends State<AdminHomeShowcasePage> {
  static const int _maxItems = 10;
  final AdminBookService _bookService = AdminBookService();
  final AdminEkService _ekService = AdminEkService();
  final AdminMagazineService _magazineService = AdminMagazineService();
  final HomeShowcaseService _showcaseService = HomeShowcaseService();

  final TextEditingController _bookSearchCtrl = TextEditingController();
  final TextEditingController _ekSearchCtrl = TextEditingController();
  final TextEditingController _magazineSearchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _ekler = [];
  List<Map<String, dynamic>> _magazines = [];
  List<Map<String, dynamic>> _bookEntries = [];
  List<Map<String, dynamic>> _ekEntries = [];
  List<Map<String, dynamic>> _magazineEntries = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  List<Map<String, dynamic>> _filteredEkler = [];
  List<Map<String, dynamic>> _filteredMagazines = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _bookSearchCtrl.addListener(_filterBooks);
    _ekSearchCtrl.addListener(_filterEkler);
    _magazineSearchCtrl.addListener(_filterMagazines);
  }

  @override
  void dispose() {
    _bookSearchCtrl.dispose();
    _ekSearchCtrl.dispose();
    _magazineSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _bookService.getAllBooks(),
        _ekService.getAll(),
        _magazineService.getMagazines(),
        _showcaseService.getByType("book"),
        _showcaseService.getByType("ek"),
        _showcaseService.getByType("magazine"),
      ]);

      setState(() {
        _books = results[0];
        _ekler = results[1];
        _magazines = results[2];
        _bookEntries = results[3];
        _ekEntries = results[4];
        _magazineEntries = results[5];
        _filteredBooks = List<Map<String, dynamic>>.from(_books);
        _filteredEkler = List<Map<String, dynamic>>.from(_ekler);
        _filteredMagazines = List<Map<String, dynamic>>.from(_magazines);
      });
    } catch (e) {
      await _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterBooks() {
    final q = _bookSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredBooks = _books.where((b) {
        final title = (b["title"] ?? "").toString().toLowerCase();
        final author = (b["author_rel"]?["name"] ?? "")
            .toString()
            .toLowerCase();
        return title.contains(q) || author.contains(q);
      }).toList();
    });
  }

  void _filterEkler() {
    final q = _ekSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredEkler = _ekler.where((ek) {
        final ad = (ek["ad"] ?? "").toString().toLowerCase();
        final aciklama = (ek["aciklama"] ?? "").toString().toLowerCase();
        return ad.contains(q) || aciklama.contains(q);
      }).toList();
    });
  }

  void _filterMagazines() {
    final q = _magazineSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredMagazines = _magazines.where((m) {
        final name = (m["name"] ?? "").toString().toLowerCase();
        final category = (m["category"] ?? "").toString().toLowerCase();
        return name.contains(q) || category.contains(q);
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

  Future<void> _addEntry({required String type, required int productId}) async {
    final entries = _entriesForType(type);
    if (entries.length >= _maxItems) {
      _showSnack("Maksimum $_maxItems ürün seçebilirsiniz.");
      return;
    }
    final exists = entries.any((e) => e["product_id"] == productId);
    if (exists) {
      _showSnack("Bu ürün zaten seçili.");
      return;
    }
    try {
      await _showcaseService.add(
        productType: type,
        productId: productId,
        sortOrder: entries.length + 1,
      );
      await _reloadEntries(type);
      _showSnack("Seçim eklendi.");
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Future<void> _removeEntry({
    required String type,
    required int entryId,
  }) async {
    try {
      await _showcaseService.delete(entryId);
      await _reloadEntries(type);
      _showSnack("Seçim kaldırıldı.");
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Future<void> _reloadEntries(String type) async {
    final list = await _showcaseService.getByType(type);
    setState(() {
      _setEntriesForType(type, list);
    });
  }

  Future<void> _persistOrder(
    String type,
    List<Map<String, dynamic>> entries,
  ) async {
    try {
      for (var i = 0; i < entries.length; i++) {
        final id = entries[i]["id"];
        if (id == null) continue;
        await _showcaseService.updateSortOrder(id: id as int, sortOrder: i + 1);
      }
      _showSnack("Sıralama güncellendi.");
    } catch (e) {
      await _showError(e.toString());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminLoadingIndicator();
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Anasayfa Gösterimi",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            "Kitap, dergi ve ekler için anasayfa sıralamasını belirleyin. Maksimum 10 ürün seçilebilir.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const TabBar(
            labelColor: Colors.red,
            tabs: [
              Tab(text: "Kitaplar"),
              Tab(text: "Dergiler"),
              Tab(text: "Ekler"),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildTypeTab(
                  type: "book",
                  entries: _bookEntries,
                  items: _filteredBooks,
                  searchController: _bookSearchCtrl,
                ),
                _buildTypeTab(
                  type: "magazine",
                  entries: _magazineEntries,
                  items: _filteredMagazines,
                  searchController: _magazineSearchCtrl,
                ),
                _buildTypeTab(
                  type: "ek",
                  entries: _ekEntries,
                  items: _filteredEkler,
                  searchController: _ekSearchCtrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String type,
    required List<Map<String, dynamic>> entries,
    required List<Map<String, dynamic>> items,
    required TextEditingController searchController,
  }) {
    final label = _typeLabel(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Seçili: ${entries.length}/$_maxItems"),
            const SizedBox(width: 12),
            const Text(
              "Sürükle-bırak ile sıralayın.",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: entries.isEmpty
              ? const Center(child: Text("Henüz seçim yok."))
              : ReorderableListView.builder(
                  itemCount: entries.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = entries.removeAt(oldIndex);
                      entries.insert(newIndex, item);
                    });
                    await _persistOrder(type, entries);
                  },
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    final itemId = entry["product_id"];
                    final title = _titleFor(type, itemId as int?);
                    return ListTile(
                      key: ValueKey("entry-${entry["id"]}"),
                      title: Text(title),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _removeEntry(
                          type: type,
                          entryId: entry["id"] as int,
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            labelText: "$label ara",
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final item = items[index];
              final itemId = item["id"] as int?;
              final title = _itemTitle(type, item);
              final subtitle = _itemSubtitle(type, item);
              final selected = entries.any((e) => e["product_id"] == itemId);
              return ListTile(
                title: Text(title),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: selected
                    ? const Icon(Icons.check, color: Colors.green)
                    : TextButton(
                        onPressed: itemId == null
                            ? null
                            : () => _addEntry(type: type, productId: itemId),
                        child: const Text("Ekle"),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _titleFor(String type, int? itemId) {
    if (itemId == null) return "Ürün";
    if (type == "book") {
      final match = _books.where((b) => b["id"] == itemId).toList();
      return match.isNotEmpty
          ? _itemTitle(type, match.first)
          : "Kitap #$itemId";
    }
    if (type == "ek") {
      final match = _ekler.where((e) => e["id"] == itemId).toList();
      return match.isNotEmpty ? _itemTitle(type, match.first) : "Ek #$itemId";
    }
    final match = _magazines.where((m) => m["id"] == itemId).toList();
    return match.isNotEmpty ? _itemTitle(type, match.first) : "Dergi #$itemId";
  }

  String _itemTitle(String type, Map<String, dynamic> item) {
    if (type == "book") return (item["title"] ?? "Kitap").toString();
    if (type == "ek") return (item["ad"] ?? "Ek").toString();
    return (item["name"] ?? "Dergi").toString();
  }

  String? _itemSubtitle(String type, Map<String, dynamic> item) {
    if (type == "book") {
      return item["author_rel"]?["name"]?.toString();
    }
    if (type == "ek") {
      final aciklama = (item["aciklama"] ?? "").toString().trim();
      if (aciklama.isNotEmpty) return aciklama;
      final fiyat = item["fiyat"]?.toString().trim() ?? "";
      return fiyat.isEmpty ? null : "Fiyat: $fiyat";
    }
    final category = item["category"]?.toString();
    return category == null || category.isEmpty ? null : category;
  }

  List<Map<String, dynamic>> _entriesForType(String type) {
    switch (type) {
      case "book":
        return _bookEntries;
      case "ek":
        return _ekEntries;
      default:
        return _magazineEntries;
    }
  }

  void _setEntriesForType(String type, List<Map<String, dynamic>> list) {
    switch (type) {
      case "book":
        _bookEntries = list;
        return;
      case "ek":
        _ekEntries = list;
        return;
      default:
        _magazineEntries = list;
        return;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case "book":
        return "Kitap";
      case "ek":
        return "Ek";
      default:
        return "Dergi";
    }
  }
}
