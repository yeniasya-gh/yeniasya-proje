import 'package:flutter/material.dart';
import '../../services/admin/admin_author_service.dart';
import '../../services/admin/admin_category_service.dart';
import '../../services/error/error_manager.dart';

class AdminAuthorCategoryPage extends StatefulWidget {
  const AdminAuthorCategoryPage({super.key});

  @override
  State<AdminAuthorCategoryPage> createState() =>
      _AdminAuthorCategoryPageState();
}

class _AdminAuthorCategoryPageState extends State<AdminAuthorCategoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final AdminAuthorService _authorService = AdminAuthorService();
  final AdminCategoryService _categoryService = AdminCategoryService();

  List<Map<String, dynamic>> authors = [];
  List<Map<String, dynamic>> categories = [];

  final TextEditingController authorSearchCtrl = TextEditingController();
  final TextEditingController categorySearchCtrl = TextEditingController();

  List<Map<String, dynamic>> filteredAuthors = [];
  List<Map<String, dynamic>> filteredCategories = [];

  bool loadingAuthors = true;
  bool loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _loadAuthors();
    _loadCategories();
  }

  Future<void> _loadAuthors() async {
    setState(() => loadingAuthors = true);
    try {
      final list = await _authorService.getAllAuthors();
      setState(() {
        authors = list;
        filteredAuthors = list;
      });
    } catch (e) {
      await _showError(e.toString());
    }
    setState(() => loadingAuthors = false);
  }

  Future<void> _loadCategories() async {
    setState(() => loadingCategories = true);
    try {
      final list = await _categoryService.getAllCategories();
      setState(() {
        categories = list;
        filteredCategories = list;
      });
    } catch (e) {
      await _showError(e.toString());
    }
    setState(() => loadingCategories = false);
  }

  void _filterAuthors(String query) {
    setState(() {
      filteredAuthors = authors.where((a) =>
        a["name"].toString().toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _filterCategories(String query) {
    setState(() {
      filteredCategories = categories.where((c) =>
        c["name"].toString().toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  // Genel error popup
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

  // YAZAR EKLE POPUP
  void _addAuthorDialog({String? initial}) {
    final ctrl = TextEditingController(text: initial ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yeni Yazar Ekle"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Yazar adı"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = ctrl.text.trim();
              if (payload.isEmpty) return;

              Navigator.pop(context);
              try {
                await _authorService.addAuthor(payload);
                _loadAuthors();
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _addAuthorDialog(initial: payload),
                  );
                }
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  // KATEGORİ EKLE POPUP
  void _addCategoryDialog({String? initial}) {
    final ctrl = TextEditingController(text: initial ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yeni Kategori Ekle"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Kategori adı"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = ctrl.text.trim();
              if (payload.isEmpty) return;

              Navigator.pop(context);
              try {
                await _categoryService.addCategory(payload);
                _loadCategories();
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _addCategoryDialog(initial: payload),
                  );
                }
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  // YAZAR DÜZENLE
  void _editAuthorDialog(Map<String, dynamic> author) {
    final ctrl = TextEditingController(text: author["name"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yazar Düzenle"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Yazar adı"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                "id": author["id"],
                "name": ctrl.text.trim(),
              };

              Navigator.pop(context);

              try {
                await _authorService.updateAuthor(
                  payload["id"] as int,
                  payload["name"] as String,
                );
                _loadAuthors();
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _editAuthorDialog(payload),
                  );
                }
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // KATEGORİ DÜZENLE
  void _editCategoryDialog(Map<String, dynamic> category) {
    final ctrl = TextEditingController(text: category["name"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kategori Düzenle"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Kategori adı"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                "id": category["id"],
                "name": ctrl.text.trim(),
              };

              Navigator.pop(context);

              try {
                await _categoryService.updateCategory(
                  payload["id"] as int,
                  payload["name"] as String,
                );
                _loadCategories();
              } catch (e) {
                await _showError(e.toString());
                if (mounted) {
                  await Future.microtask(
                    () => _editCategoryDialog(payload),
                  );
                }
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // YAZAR SİL
  void _deleteAuthor(int id) async {
    await _authorService.deleteAuthor(id);
    _loadAuthors();
  }

  // KATEGORİ SİL
  void _deleteCategory(int id) async {
    await _categoryService.deleteCategory(id);
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: "Yazarlar"),
            Tab(text: "Kategoriler"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildAuthorsTab(), _buildCategoriesTab()],
          ),
        ),
      ],
    );
  }

  // ------------------ YAZARLAR TAB -------------------
Widget _buildAuthorsTab() {
  return Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Yazar Ekle"),
            onPressed: _addAuthorDialog,
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: authorSearchCtrl,
          onChanged: _filterAuthors,
          decoration: const InputDecoration(
            labelText: "Yazar Ara",
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),

      Expanded(
        child: ListView(
          children: filteredAuthors.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final a = entry.value;
            return ListTile(
              leading: Text(index.toString()),
              title: Text(a["name"]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editAuthorDialog(a),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteAuthor(a["id"]),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}

  // ------------------ KATEGORİLER TAB -------------------
Widget _buildCategoriesTab() {
  return Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Kategori Ekle"),
            onPressed: _addCategoryDialog,
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: categorySearchCtrl,
          onChanged: _filterCategories,
          decoration: const InputDecoration(
            labelText: "Kategori Ara",
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),

      Expanded(
        child: ListView(
          children: filteredCategories.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final c = entry.value;
            return ListTile(
              leading: Text(index.toString()),
              title: Text(c["name"]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editCategoryDialog(c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCategory(c["id"]),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}
}
