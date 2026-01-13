import 'package:flutter/material.dart';

import '../../services/admin/admin_book_service.dart';
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
  final AdminMagazineService _magazineService = AdminMagazineService();
  final HomeShowcaseService _showcaseService = HomeShowcaseService();

  final TextEditingController _bookSearchCtrl = TextEditingController();
  final TextEditingController _magazineSearchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _magazines = [];
  List<Map<String, dynamic>> _bookEntries = [];
  List<Map<String, dynamic>> _magazineEntries = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  List<Map<String, dynamic>> _filteredMagazines = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _bookSearchCtrl.addListener(_filterBooks);
    _magazineSearchCtrl.addListener(_filterMagazines);
  }

  @override
  void dispose() {
    _bookSearchCtrl.dispose();
    _magazineSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _bookService.getAllBooks(),
        _magazineService.getMagazines(),
        _showcaseService.getByType("book"),
        _showcaseService.getByType("magazine"),
      ]);

      setState(() {
        _books = results[0] as List<Map<String, dynamic>>;
        _magazines = results[1] as List<Map<String, dynamic>>;
        _bookEntries = results[2] as List<Map<String, dynamic>>;
        _magazineEntries = results[3] as List<Map<String, dynamic>>;
        _filteredBooks = List<Map<String, dynamic>>.from(_books);
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
        final author = (b["author_rel"]?["name"] ?? "").toString().toLowerCase();
        return title.contains(q) || author.contains(q);
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

  Future<void> _addEntry({
    required String type,
    required int productId,
  }) async {
    final entries = type == "book" ? _bookEntries : _magazineEntries;
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
      if (type == "book") {
        _bookEntries = list;
      } else {
        _magazineEntries = list;
      }
    });
  }

  Future<void> _persistOrder(String type, List<Map<String, dynamic>> entries) async {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AdminLoadingIndicator();
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Anasayfa Gösterimi",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            "Kitap ve dergiler için anasayfa sıralamasını belirleyin. Maksimum 10 ürün seçilebilir.",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const TabBar(
            labelColor: Colors.red,
            tabs: [
              Tab(text: "Kitaplar"),
              Tab(text: "Dergiler"),
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
    final isBook = type == "book";
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
            labelText: isBook ? "Kitap ara" : "Dergi ara",
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
      return match.isNotEmpty ? _itemTitle(type, match.first) : "Kitap #$itemId";
    }
    final match = _magazines.where((m) => m["id"] == itemId).toList();
    return match.isNotEmpty ? _itemTitle(type, match.first) : "Dergi #$itemId";
  }

  String _itemTitle(String type, Map<String, dynamic> item) {
    if (type == "book") return (item["title"] ?? "Kitap").toString();
    return (item["name"] ?? "Dergi").toString();
  }

  String? _itemSubtitle(String type, Map<String, dynamic> item) {
    if (type == "book") {
      return item["author_rel"]?["name"]?.toString();
    }
    final category = item["category"]?.toString();
    return category == null || category.isEmpty ? null : category;
  }
}
