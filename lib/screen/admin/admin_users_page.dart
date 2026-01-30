import 'package:flutter/material.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/admin/admin_magazine_type_service.dart';
import '../../services/admin/admin_newspaper_subscription_type_service.dart';
import '../../services/admin/admin_ek_service.dart';
import '../../services/user_content_access_service.dart';
import 'admin_user_detail_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController searchCtrl = TextEditingController();
  final AdminUserService _adminService = AdminUserService();

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<Map<String, dynamic>> allRoles = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => isLoading = true);

    try {
      final users = await _adminService.getAllUsers();
      final roles = await _adminService.getAllRoles();

      setState(() {
        allUsers = users;
        filteredUsers = users;
        allRoles = roles;
      });
    } catch (e) {
      _showError("Kullanıcılar yüklenirken hata oluştu:\n$e");
    }

    setState(() => isLoading = false);
  }

  void _filter(String text) {
    setState(() {
      filteredUsers = allUsers
          .where(
            (u) =>
                u["name"].toLowerCase().contains(text.toLowerCase()) ||
                u["email"].toLowerCase().contains(text.toLowerCase()),
          )
          .toList();
    });
  }

  // ❗ Hata göstermek için
  Future<void> _showError(String rawError) {
    final parsed = ErrorManager.parseGraphQLError(rawError);

    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hata"),
        content: Text(parsed),
        actions: [
          TextButton(
            child: const Text("Tamam"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  // ❌ Kullanıcı sil
  void _deleteUser(int id) async {
    try {
      final ok = await _adminService.deleteUser(id);
      if (ok) {
        _loadUsers();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Kullanıcı silindi")));
      }
    } catch (e) {
      _showError("Kullanıcı silinemedi:\n$e");
    }
  }

  void _openUserDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailPage(user: user),
      ),
    );
  }

  // ➕ Kullanıcı ekleme popup
  void _showAddUserDialog({Map<String, String>? initialData}) {
    final nameCtrl = TextEditingController(text: initialData?["name"] ?? "");
    final emailCtrl = TextEditingController(text: initialData?["email"] ?? "");
    final passCtrl = TextEditingController(text: initialData?["password"] ?? "");
    final phoneCtrl = TextEditingController(text: initialData?["phone"] ?? "");

    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Yeni Kullanıcı Ekle"),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Ad Soyad"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Bu alan zorunlu" : null,
                  ),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: "E-posta"),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "E-posta gerekli";
                      if (!v.contains("@")) return "Geçerli mail girin";
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: "Telefon"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Telefon gerekli" : null,
                  ),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Şifre"),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Şifre gerekli";
                      if (v.length < 6) return "Min 6 karakter olmalı";
                      return null;
                    },
                  ),
                ],
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
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                final payload = {
                  "name": nameCtrl.text,
                  "email": emailCtrl.text,
                  "password": passCtrl.text,
                  "phone": phoneCtrl.text,
                };

                Navigator.pop(context);

                try {
                  await _adminService.addUser(
                    name: payload["name"] ?? "",
                    email: payload["email"] ?? "",
                    password: payload["password"] ?? "",
                    phone: payload["phone"],
                  );
                  _loadUsers();
                } catch (e) {
                  await _showError(e.toString());
                  if (mounted) {
                    await Future.microtask(
                      () => _showAddUserDialog(initialData: payload),
                    );
                  }
                }
              },
              child: const Text(
                "Kaydet",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✏️ Kullanıcı düzenleme popup
  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user["name"]);
    final emailCtrl = TextEditingController(text: user["email"]);
    final phoneCtrl = TextEditingController(text: user["phone"] ?? "");
    int roleId = user["role_id"] ?? 1;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Kullanıcı Düzenle"),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Ad Soyad"),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "E-posta"),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: "Telefon"),
                ),
                DropdownButtonFormField<int>(
                  value: roleId,
                  decoration: const InputDecoration(labelText: "Rol"),
                  items: allRoles.map((r) =>
                    DropdownMenuItem<int>(
                      value: r["id"],
                      child: Text(r["name"]),
                    ),
                  ).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => roleId = v);
                    }
                  },
                ),
              ],
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
                final payload = {
                  "id": user["id"],
                  "name": nameCtrl.text,
                  "email": emailCtrl.text,
                  "phone": phoneCtrl.text,
                  "role_id": roleId,
                };

                Navigator.pop(context);

                try {
                  await _adminService.updateUser(
                    id: payload["id"] as int,
                    name: payload["name"] as String,
                    email: payload["email"] as String,
                    phone: payload["phone"] as String?,
                    roleId: payload["role_id"] as int,
                  );
                  _loadUsers();
                } catch (e) {
                  await _showError("Güncelleme hatası:\n$e");
                  if (mounted) {
                    await Future.microtask(
                      () => _showEditUserDialog(payload),
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

  void _showGrantAccessDialog(Map<String, dynamic> user) async {
    final accessService = UserContentAccessService();
    final bookService = AdminBookService();
    final magazineService = AdminMagazineService();
    final magazineTypeService = AdminMagazineTypeService();
    final searchTypeService = AdminNewspaperSubscriptionTypeService();
    final ekService = AdminEkService();

    String? selectedCategory; // 'book', 'magazine', 'newspaper', 'ek'
    dynamic selectedItem;
    dynamic selectedSubType; // for magazine subscription duration
    List<dynamic> items = [];
    List<dynamic> subTypes = [];
    bool loadingItems = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text("${user["name"]} - Erişim Tanımla"),
          content: SizedBox(
            width: 450,
            child: isSaving
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: CircularProgressIndicator(),
                      ),
                      Text("Erişim tanımlanıyor..."),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: "Kategori"),
                        items: const [
                          DropdownMenuItem(value: "book", child: Text("Kitap")),
                          DropdownMenuItem(
                              value: "magazine", child: Text("Dergi (Abonelik)")),
                          DropdownMenuItem(
                              value: "newspaper",
                              child: Text("E-Gazete (Abonelik)")),
                          DropdownMenuItem(value: "ek", child: Text("Ek")),
                        ],
                        onChanged: (val) async {
                          setSt(() {
                            selectedCategory = val;
                            selectedItem = null;
                            selectedSubType = null;
                            items = [];
                            subTypes = [];
                            loadingItems = true;
                          });

                          try {
                            if (val == "book") {
                              items = await bookService.getAllBooks();
                            } else if (val == "magazine") {
                              items = await magazineService.getMagazines();
                              subTypes = await magazineTypeService.getAll();
                            } else if (val == "newspaper") {
                              items = await searchTypeService.getAll();
                            } else if (val == "ek") {
                              items = await ekService.getAll();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text("Yükleme hatası: $e")));
                            }
                          } finally {
                            setSt(() => loadingItems = false);
                          }
                        },
                      ),
                      if (loadingItems)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      if (!loadingItems && selectedCategory != null) ...[
                        const SizedBox(height: 12),
                        if (selectedCategory == "book")
                          DropdownButtonFormField<dynamic>(
                            value: selectedItem,
                            decoration: const InputDecoration(labelText: "Kitap Seçin"),
                            items: items
                                .map((i) => DropdownMenuItem(
                                    value: i, child: Text(i["title"] ?? "")))
                                .toList(),
                            onChanged: (val) => setSt(() => selectedItem = val),
                          ),
                        if (selectedCategory == "magazine") ...[
                          DropdownButtonFormField<dynamic>(
                            value: selectedItem,
                            decoration:
                                const InputDecoration(labelText: "Dergi Seçin"),
                            items: items
                                .map((i) => DropdownMenuItem(
                                    value: i, child: Text(i["name"] ?? "")))
                                .toList(),
                            onChanged: (val) => setSt(() => selectedItem = val),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<dynamic>(
                            value: selectedSubType,
                            decoration:
                                const InputDecoration(labelText: "Abonelik Süresi"),
                            items: subTypes
                                .map((i) => DropdownMenuItem(
                                    value: i, child: Text(i["title"] ?? "")))
                                .toList(),
                            onChanged: (val) => setSt(() => selectedSubType = val),
                          ),
                        ],
                        if (selectedCategory == "newspaper")
                          DropdownButtonFormField<dynamic>(
                            value: selectedItem,
                            decoration:
                                const InputDecoration(labelText: "Abonelik Tipi"),
                            items: items
                                .map((i) => DropdownMenuItem(
                                    value: i, child: Text(i["title"] ?? "")))
                                .toList(),
                            onChanged: (val) => setSt(() => selectedItem = val),
                          ),
                        if (selectedCategory == "ek")
                          DropdownButtonFormField<dynamic>(
                            value: selectedItem,
                            decoration: const InputDecoration(labelText: "Ek Seçin"),
                            items: items
                                .map((i) => DropdownMenuItem(
                                    value: i, child: Text(i["ad"] ?? "")))
                                .toList(),
                            onChanged: (val) => setSt(() => selectedItem = val),
                          ),
                      ],
                    ],
                  ),
          ),
          actions: isSaving
              ? null
              : [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("İptal")),
                  ElevatedButton(
                    onPressed: selectedItem == null
                        ? null
                        : () async {
                            setSt(() => isSaving = true);
                            try {
                              String itemType = "";
                              int? itemId;
                              DateTime? expiresAt;
                              double price = 0;

                              if (selectedCategory == "book") {
                                itemType = "book";
                                itemId = selectedItem["id"];
                                price = double.tryParse(
                                        selectedItem["price"]?.toString() ??
                                            "0") ??
                                    0;
                              } else if (selectedCategory == "magazine") {
                                if (selectedSubType == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("Lütfen abonelik tipi seçin")));
                                  setSt(() => isSaving = false);
                                  return;
                                }
                                itemType = "magazine";
                                itemId = selectedItem["id"];
                                final months = (selectedSubType["duration_months"]
                                            as num?)
                                        ?.toInt() ??
                                    1;
                                expiresAt = DateTime.now()
                                    .add(Duration(days: 30 * months));
                                price = 0; // Manuel tanımlama
                              } else if (selectedCategory == "newspaper") {
                                itemType = "newspaper_subscription";
                                itemId = null; // Genel abonelik
                                final months =
                                    (selectedItem["duration_months"] as num?)
                                            ?.toInt() ??
                                        1;
                                expiresAt = DateTime.now()
                                    .add(Duration(days: 30 * months));
                                price = 0;
                              } else if (selectedCategory == "ek") {
                                itemType = "ek";
                                itemId = selectedItem["id"];
                                price = double.tryParse(
                                        selectedItem["fiyat"]?.toString() ??
                                            "0") ??
                                    0;
                              }

                              await accessService.grantAccess(
                                userId: user["id"].toString(),
                                items: [
                                  {
                                    "item_type": itemType,
                                    "item_id": itemId,
                                    "started_at": DateTime.now().toIso8601String(),
                                    "expires_at": expiresAt?.toIso8601String(),
                                    "purchase_price": price,
                                  }
                                ],
                              );

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Erişim başarıyla tanımlandı")));
                              }
                            } catch (e) {
                              setSt(() => isSaving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text("Hata: $e")));
                            }
                          },
                    child: const Text("Tanımla"),
                  ),
                ],
        ),
      ),
    );
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
              "Kullanıcı Yönetimi",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Kullanıcı Ekle",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _showAddUserDialog,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Arama
        TextField(
          controller: searchCtrl,
          onChanged: _filter,
          decoration: InputDecoration(
            hintText: "Kullanıcı ara...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 20),

        // TABLO (Full Width)
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
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: double.infinity),
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.grey.shade100),
                    columns: const [
                      DataColumn(label: Text("#")),
                      DataColumn(label: Text("Ad Soyad")),
                      DataColumn(label: Text("E-posta")),
                      DataColumn(label: Text("Rol")),
                      DataColumn(label: Text("İşlem")),
                    ],
                    rows: filteredUsers.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final u = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(Text(index.toString())),
                          DataCell(Text(u["name"])),
                          DataCell(Text(u["email"])),
                          DataCell(Text(u["role"])),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () => _showGrantAccessDialog(u),
                                  tooltip: "Erişim Tanımla",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: Colors.teal),
                                  onPressed: () => _openUserDetail(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showEditUserDialog(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteUser(u["id"]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
