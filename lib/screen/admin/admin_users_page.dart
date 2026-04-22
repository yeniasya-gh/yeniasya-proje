import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/admin/admin_users_excel_export_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/admin/admin_magazine_type_service.dart';
import '../../services/admin/admin_newspaper_subscription_type_service.dart';
import '../../services/admin/admin_ek_service.dart';
import '../../services/admin/admin_user_access_audit_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/user_content_access_service.dart';
import '../../utils/excel_export_helper.dart';
import 'admin_passive_users_page.dart';
import 'admin_user_detail_page.dart';

class AdminUsersPage extends StatefulWidget {
  final AdminUserService? adminService;
  final AdminUserAccessAuditService? auditService;

  const AdminUsersPage({super.key, this.adminService, this.auditService});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController searchCtrl = TextEditingController();
  late final AdminUserService _adminService;
  late final AdminUserAccessAuditService _auditService;
  late final AdminUsersExcelExportService _excelExportService;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> allRoles = [];

  bool isLoading = true;
  bool isExporting = false;
  int _currentPage = 1;
  int _totalCount = 0;
  static const int _pageSize = 25;
  String _currentSearch = "";
  int _usersRequestSeq = 0;

  @override
  void initState() {
    super.initState();
    _adminService = widget.adminService ?? AdminUserService();
    _auditService = widget.auditService ?? AdminUserAccessAuditService();
    _excelExportService = AdminUsersExcelExportService(
      userService: _adminService,
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadRoles(), _loadUsers(page: 1, search: "")]);
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _adminService.getAllRoles();
      if (!mounted) return;
      setState(() {
        allRoles = roles;
      });
    } catch (e) {
      if (mounted) {
        await _showError("Roller yüklenirken hata oluştu:\n$e");
      }
    }
  }

  Future<void> _loadUsers({required int page, String? search}) async {
    final query = (search ?? searchCtrl.text).trim();
    final safePage = page < 1 ? 1 : page;
    final requestSeq = ++_usersRequestSeq;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final result = await _adminService.getUsersPage(
        search: query,
        page: safePage,
        pageSize: _pageSize,
      );

      final users = List<Map<String, dynamic>>.from(
        result["users"] ?? const [],
      );
      final totalCount = result["totalCount"] is int
          ? result["totalCount"] as int
          : int.tryParse(result["totalCount"]?.toString() ?? "") ?? 0;
      final totalPages = totalCount <= 0
          ? 1
          : ((totalCount + _pageSize - 1) ~/ _pageSize);
      if (safePage > totalPages && totalCount > 0) {
        await _loadUsers(page: totalPages, search: query);
        return;
      }

      if (!mounted || requestSeq != _usersRequestSeq) return;
      setState(() {
        _users = users;
        _totalCount = totalCount;
        _currentPage = safePage;
        _currentSearch = query;
      });
    } catch (e) {
      if (mounted) {
        await _showError("Kullanıcılar yüklenirken hata oluştu:\n$e");
      }
    } finally {
      if (mounted && requestSeq == _usersRequestSeq) {
        setState(() => isLoading = false);
      }
    }
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadUsers(page: 1, search: value);
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
          ),
        ],
      ),
    );
  }

  // ❌ Kullanıcı sil
  Future<void> _deleteUser(int id) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await _adminService.deleteUser(id);
      if (!mounted) return;
      if (ok) {
        await _loadUsers(page: _currentPage, search: searchCtrl.text);
        messenger.showSnackBar(
          const SnackBar(content: Text("Kullanıcı pasif hale getirildi")),
        );
      } else {
        await _showError("Kullanıcı silinemedi.");
      }
    } catch (e) {
      await _showError("Kullanıcı silinemedi:\n$e");
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final userId = user["id"];
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Kullanıcı pasif hale getirilsin mi?"),
        content: Text(
          "${user["name"] ?? "Bu kullanıcı"} pasif hale getirilecek.\n"
          "Kayıt verileri korunacak, aktif kullanıcı listesinden gizlenecek ve giriş yapamayacak.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Pasife Al"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final parsedUserId = _asInt(userId);
      if (parsedUserId == null) return;
      await _deleteUser(parsedUserId);
    }
  }

  void _openUserDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserDetailPage(user: user)),
    );
  }

  void _openPassiveUsersPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPassiveUsersPage(
          adminService: _adminService,
          auditService: _auditService,
        ),
      ),
    );
  }

  Future<void> _exportUsersToExcel() async {
    if (isLoading || isExporting) return;

    setState(() => isExporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final export = await _excelExportService.exportUsersWorkbook();
      await exportExcelBytes(export.bytes, export.fileName);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "${export.userCount} kullanıcı, ${export.accessCount} abonelik satırı ve ${export.orderCount} sipariş Excel'e aktarıldı.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showError("Excel export sırasında hata oluştu:\n$e");
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }

  // ➕ Kullanıcı ekleme popup
  void _showAddUserDialog({Map<String, String>? initialData}) {
    final nameCtrl = TextEditingController(text: initialData?["name"] ?? "");
    final emailCtrl = TextEditingController(text: initialData?["email"] ?? "");
    final passCtrl = TextEditingController(
      text: initialData?["password"] ?? "",
    );
    final phoneCtrl = TextEditingController(text: initialData?["phone"] ?? "");
    final pageMessenger = ScaffoldMessenger.of(context);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Yeni Kullanıcı Ekle"),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
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
                    if (isSaving) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text("Kullanıcı kaydediliyor...")),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text("Kapat"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        final payload = {
                          "name": nameCtrl.text.trim(),
                          "email": emailCtrl.text.trim(),
                          "password": passCtrl.text,
                          "phone": phoneCtrl.text.trim(),
                        };

                        setDialogState(() => isSaving = true);

                        try {
                          await _adminService.addUser(
                            name: payload["name"] ?? "",
                            email: payload["email"] ?? "",
                            password: payload["password"] ?? "",
                            phone: payload["phone"],
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          await _loadUsers(page: 1, search: searchCtrl.text);
                          if (!mounted) return;
                          pageMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Kullanıcı eklendi ve liste güncellendi.",
                              ),
                            ),
                          );
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                          if (!mounted) return;
                          pageMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ErrorManager.parseGraphQLError(e.toString()),
                              ),
                            ),
                          );
                        }
                      },
                child: const Text(
                  "Kaydet",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
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
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
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
                    initialValue: roleId,
                    decoration: const InputDecoration(labelText: "Rol"),
                    items: allRoles
                        .map(
                          (r) => DropdownMenuItem<int>(
                            value: r["id"],
                            child: Text(r["name"]),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => roleId = v);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Kapat"),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "Kaydet",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  final payload = {
                    "id": user["id"],
                    "name": nameCtrl.text,
                    "email": emailCtrl.text,
                    "phone": phoneCtrl.text,
                    "role_id": roleId,
                  };

                  Navigator.pop(dialogContext);

                  try {
                    await _adminService.updateUser(
                      id: payload["id"] as int,
                      name: payload["name"] as String,
                      email: payload["email"] as String,
                      phone: payload["phone"] as String?,
                      roleId: payload["role_id"] as int,
                    );
                    await _loadUsers(
                      page: _currentPage,
                      search: searchCtrl.text,
                    );
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
          ),
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
    final authProvider = context.read<AuthProvider>();
    final pageMessenger = ScaffoldMessenger.of(context);

    String? selectedCategory; // 'book', 'magazine', 'newspaper', 'ek'
    dynamic selectedItem;
    dynamic selectedSubType; // for magazine subscription duration
    List<dynamic> items = [];
    List<dynamic> subTypes = [];
    bool loadingItems = false;
    bool loadingExistingSubscription = false;
    bool isSaving = false;
    Map<String, dynamic>? existingSubscription;
    DateTime? projectedExpiry;
    bool willExtendExistingSubscription = false;
    var previewRequestId = 0;

    Future<void> refreshSubscriptionPreview(
      BuildContext dialogContext,
      StateSetter setSt,
    ) async {
      final category = selectedCategory;
      if (category != "magazine" && category != "newspaper") {
        setSt(() {
          loadingExistingSubscription = false;
          existingSubscription = null;
          projectedExpiry = null;
          willExtendExistingSubscription = false;
        });
        return;
      }

      int? itemId;
      int? durationMonths;
      String? itemType;

      if (category == "magazine") {
        if (selectedItem == null || selectedSubType == null) {
          setSt(() {
            loadingExistingSubscription = false;
            existingSubscription = null;
            projectedExpiry = null;
            willExtendExistingSubscription = false;
          });
          return;
        }
        itemType = "magazine";
        itemId = _asInt(selectedItem["id"]);
        durationMonths = (selectedSubType["duration_months"] as num?)?.toInt();
      } else {
        if (selectedItem == null) {
          setSt(() {
            loadingExistingSubscription = false;
            existingSubscription = null;
            projectedExpiry = null;
            willExtendExistingSubscription = false;
          });
          return;
        }
        itemType = "newspaper_subscription";
        durationMonths = (selectedItem["duration_months"] as num?)?.toInt();
      }

      if (durationMonths == null || durationMonths <= 0) {
        setSt(() {
          loadingExistingSubscription = false;
          existingSubscription = null;
          projectedExpiry = null;
          willExtendExistingSubscription = false;
        });
        return;
      }

      final requestId = ++previewRequestId;
      setSt(() {
        loadingExistingSubscription = true;
        existingSubscription = null;
        projectedExpiry = null;
        willExtendExistingSubscription = false;
      });

      try {
        final current = await accessService.getLatestGrantableAccessEntry(
          userId: user["id"] as int,
          itemType: itemType,
          itemId: itemId,
        );
        if (!dialogContext.mounted || requestId != previewRequestId) return;

        final now = DateTime.now();
        final currentExpiry = _parseDateTime(current?["expires_at"]);
        final isCurrentlyActive =
            currentExpiry != null && currentExpiry.isAfter(now);
        final baseDate = isCurrentlyActive ? currentExpiry : now;

        setSt(() {
          loadingExistingSubscription = false;
          existingSubscription = current;
          willExtendExistingSubscription = isCurrentlyActive;
          projectedExpiry = _addMonths(baseDate, durationMonths!);
        });
      } catch (_) {
        if (!dialogContext.mounted || requestId != previewRequestId) return;
        setSt(() {
          loadingExistingSubscription = false;
          existingSubscription = null;
          projectedExpiry = null;
          willExtendExistingSubscription = false;
        });
      }
    }

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
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: "Kategori",
                        ),
                        items: const [
                          DropdownMenuItem(value: "book", child: Text("Kitap")),
                          DropdownMenuItem(
                            value: "magazine",
                            child: Text("Dergi (Abonelik)"),
                          ),
                          DropdownMenuItem(
                            value: "newspaper",
                            child: Text("E-Gazete (Abonelik)"),
                          ),
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
                            loadingExistingSubscription = false;
                            existingSubscription = null;
                            projectedExpiry = null;
                            willExtendExistingSubscription = false;
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
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text("Yükleme hatası: $e")),
                              );
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
                            initialValue: selectedItem,
                            decoration: const InputDecoration(
                              labelText: "Kitap Seçin",
                            ),
                            items: items
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(i["title"] ?? ""),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setSt(() => selectedItem = val);
                            },
                          ),
                        if (selectedCategory == "magazine") ...[
                          DropdownButtonFormField<dynamic>(
                            initialValue: selectedItem,
                            decoration: const InputDecoration(
                              labelText: "Dergi Seçin",
                            ),
                            items: items
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(i["name"] ?? ""),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              setSt(() => selectedItem = val);
                              await refreshSubscriptionPreview(context, setSt);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<dynamic>(
                            initialValue: selectedSubType,
                            decoration: const InputDecoration(
                              labelText: "Abonelik Süresi",
                            ),
                            items: subTypes
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(i["title"] ?? ""),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              setSt(() => selectedSubType = val);
                              await refreshSubscriptionPreview(context, setSt);
                            },
                          ),
                        ],
                        if (selectedCategory == "newspaper")
                          DropdownButtonFormField<dynamic>(
                            initialValue: selectedItem,
                            decoration: const InputDecoration(
                              labelText: "Abonelik Tipi",
                            ),
                            items: items
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(i["title"] ?? ""),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              setSt(() => selectedItem = val);
                              await refreshSubscriptionPreview(context, setSt);
                            },
                          ),
                        if (selectedCategory == "ek")
                          DropdownButtonFormField<dynamic>(
                            initialValue: selectedItem,
                            decoration: const InputDecoration(
                              labelText: "Ek Seçin",
                            ),
                            items: items
                                .map(
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(i["ad"] ?? ""),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setSt(() => selectedItem = val);
                            },
                          ),
                        if ((selectedCategory == "magazine" ||
                                selectedCategory == "newspaper") &&
                            (loadingExistingSubscription ||
                                projectedExpiry != null)) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: loadingExistingSubscription
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Mevcut abonelik süresi kontrol ediliyor...",
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        willExtendExistingSubscription
                                            ? "Mevcut aktif abonelik bulundu. Yeni tanımlama mevcut sürenin üzerine eklenecek."
                                            : (_parseDateTime(
                                                        existingSubscription?["expires_at"],
                                                      ) !=
                                                      null
                                                  ? "Önceki abonelik süresi dolmuş. Yeni tanımlama yeni bir dönem başlatacak."
                                                  : "Bu kullanıcı için aktif abonelik bulunmuyor. Yeni tanımlama yeni bir dönem başlatacak."),
                                        style: const TextStyle(height: 1.4),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_parseDateTime(
                                            existingSubscription?["expires_at"],
                                          ) !=
                                          null)
                                        Text(
                                          "Mevcut bitiş: ${_formatDate(_parseDateTime(existingSubscription?["expires_at"]))}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (projectedExpiry != null)
                                        Text(
                                          "Yeni bitiş: ${_formatDate(projectedExpiry)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
          actions: isSaving
              ? null
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("İptal"),
                  ),
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
                                price =
                                    double.tryParse(
                                      selectedItem["price"]?.toString() ?? "0",
                                    ) ??
                                    0;
                              } else if (selectedCategory == "magazine") {
                                if (selectedSubType == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Lütfen abonelik tipi seçin",
                                      ),
                                    ),
                                  );
                                  setSt(() => isSaving = false);
                                  return;
                                }
                                itemType = "magazine";
                                itemId = selectedItem["id"];
                                final months =
                                    (selectedSubType["duration_months"] as num?)
                                        ?.toInt() ??
                                    1;
                                expiresAt = _addMonths(DateTime.now(), months);
                                price = 0; // Manuel tanımlama
                              } else if (selectedCategory == "newspaper") {
                                itemType = "newspaper_subscription";
                                itemId = null; // Genel abonelik
                                final months =
                                    (selectedItem["duration_months"] as num?)
                                        ?.toInt() ??
                                    1;
                                expiresAt = _addMonths(DateTime.now(), months);
                                price = 0;
                              } else if (selectedCategory == "ek") {
                                itemType = "ek";
                                itemId = selectedItem["id"];
                                price =
                                    double.tryParse(
                                      selectedItem["fiyat"]?.toString() ?? "0",
                                    ) ??
                                    0;
                              }

                              await accessService.grantAccess(
                                userId: user["id"].toString(),
                                items: [
                                  {
                                    "item_type": itemType,
                                    "item_id": itemId,
                                    "started_at": DateTime.now()
                                        .toIso8601String(),
                                    "expires_at": expiresAt?.toIso8601String(),
                                    "purchase_price": price,
                                  },
                                ],
                              );

                              try {
                                final actor = authProvider.user;
                                await _auditService.logEntry(
                                  userId: user["id"] as int,
                                  actorUserId: actor?.id,
                                  action: willExtendExistingSubscription
                                      ? "extend"
                                      : "grant",
                                  itemType: itemType,
                                  itemId: itemId,
                                  itemTitle: _resolveGrantItemTitle(
                                    selectedCategory: selectedCategory,
                                    selectedItem: selectedItem,
                                  ),
                                  accessSource: willExtendExistingSubscription
                                      ? (existingSubscription?["source"]
                                                ?.toString() ??
                                            "user_content_access")
                                      : "user_content_access",
                                  previousExpiresAt: _parseDateTime(
                                    existingSubscription?["expires_at"],
                                  ),
                                  newExpiresAt: projectedExpiry ?? expiresAt,
                                  note: "Admin paneli erişim tanımlama",
                                );
                              } catch (_) {
                                // Audit log migration'ı henüz uygulanmadıysa ana akışı bozma.
                              }

                              if (!mounted || !ctx.mounted) return;
                              Navigator.pop(ctx);
                              pageMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    willExtendExistingSubscription &&
                                            projectedExpiry != null
                                        ? "Mevcut abonelik ${_formatDate(projectedExpiry)} tarihine kadar uzatıldı."
                                        : "Erişim başarıyla tanımlandı.",
                                  ),
                                ),
                              );
                            } catch (e) {
                              setSt(() => isSaving = false);
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text("Hata: $e")),
                              );
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
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            const Text(
              "Kullanıcı Yönetimi",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_off),
                  label: const Text("Pasif Kullanıcılar"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: _openPassiveUsersPage,
                ),
                OutlinedButton.icon(
                  icon: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    isExporting ? "Hazırlanıyor..." : "Excel'e Aktar",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                  onPressed: isExporting ? null : _exportUsersToExcel,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Kullanıcı Ekle",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _showAddUserDialog,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Arama
        TextField(
          controller: searchCtrl,
          onChanged: _scheduleSearch,
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
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _users.isEmpty
                      ? const Center(child: Text("Kullanıcı bulunamadı."))
                      : SingleChildScrollView(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: double.infinity,
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade100,
                                ),
                                columns: const [
                                  DataColumn(label: Text("#")),
                                  DataColumn(label: Text("Ad Soyad")),
                                  DataColumn(label: Text("E-posta")),
                                  DataColumn(label: Text("Rol")),
                                  DataColumn(label: Text("İşlem")),
                                ],
                                rows: _users.asMap().entries.map((entry) {
                                  final index =
                                      ((_currentPage - 1) * _pageSize) +
                                      entry.key +
                                      1;
                                  final u = entry.value;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(index.toString())),
                                      DataCell(Text(u["name"] ?? "-")),
                                      DataCell(Text(u["email"] ?? "-")),
                                      DataCell(Text(u["role"] ?? "-")),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                color: Colors.green,
                                              ),
                                              onPressed: () =>
                                                  _showGrantAccessDialog(u),
                                              tooltip: "Erişim Tanımla",
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.info_outline,
                                                color: Colors.teal,
                                              ),
                                              onPressed: () =>
                                                  _openUserDetail(u),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () =>
                                                  _showEditUserDialog(u),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  _confirmDeleteUser(u),
                                              tooltip: "Pasife Al",
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Toplam $_totalCount kullanıcı${_currentSearch.isNotEmpty ? " • Arama: $_currentSearch" : ""} • Sayfa $_currentPage / ${_totalPages()}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_currentPage <= 1 || isLoading)
                              ? null
                              : () => _loadUsers(
                                  page: _currentPage - 1,
                                  search: searchCtrl.text,
                                ),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text("Önceki"),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed:
                              (_currentPage >= _totalPages() || isLoading)
                              ? null
                              : () => _loadUsers(
                                  page: _currentPage + 1,
                                  search: searchCtrl.text,
                                ),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text("Sonraki"),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DateTime _addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day);
  }

  DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
    final day = date.day.toString().padLeft(2, "0");
    final month = date.month.toString().padLeft(2, "0");
    return "$day.$month.${date.year}";
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String? _resolveGrantItemTitle({
    required String? selectedCategory,
    required dynamic selectedItem,
  }) {
    if (selectedItem == null) return null;
    switch (selectedCategory) {
      case "book":
        return selectedItem["title"]?.toString();
      case "magazine":
        return selectedItem["name"]?.toString();
      case "newspaper":
        return selectedItem["title"]?.toString();
      case "ek":
        return selectedItem["ad"]?.toString();
      default:
        return null;
    }
  }

  int _totalPages() {
    if (_totalCount <= 0) return 1;
    return ((_totalCount + _pageSize - 1) ~/ _pageSize);
  }
}
