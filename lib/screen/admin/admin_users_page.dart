import 'package:flutter/material.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/error/error_manager.dart';

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
