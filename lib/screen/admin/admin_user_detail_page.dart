import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/address_service.dart';
import '../../services/admin/admin_user_access_audit_service.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/order_service.dart';
import '../../utils/admin_user_detail_metrics.dart';
import '../../utils/order_item_visual.dart';
import '../../utils/purchase_channel_labels.dart';
import 'admin_loading_indicator.dart';

class AdminUserDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailPage({super.key, required this.user});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final AdminUserService _adminService = AdminUserService();
  final AdminUserAccessAuditService _auditService =
      AdminUserAccessAuditService();
  final OrderService _orderService = OrderService();
  final AddressService _addressService = AddressService();

  bool _loading = true;
  String? _removingAccessKey;
  String? _pageError;
  _AccessStatusFilter _statusFilter = _AccessStatusFilter.all;
  _AccessTypeFilter _typeFilter = _AccessTypeFilter.all;
  Map<String, dynamic> _userDetails = {};
  List<Map<String, dynamic>> _access = [];
  List<Map<String, dynamic>> _accessLogs = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _addresses = [];
  final Map<String, String> _sectionErrors = {};
  bool _revenueCatReconcileLoading = false;
  String? _revenueCatReconcileMessage;
  bool? _revenueCatReconcileSuccess;
  bool _passwordUpdateLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final userId = _asInt(widget.user["id"]);
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageError = "Kullanıcı ID bilgisi okunamadı.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _pageError = null;
      _sectionErrors.clear();
    });

    final results = await Future.wait<dynamic>([
      _loadSection<Map<String, dynamic>?>(
        "user",
        () => _adminService.getUserDetail(userId),
      ),
      _loadSection<List<Map<String, dynamic>>>(
        "access",
        () => _adminService.getAllAccess(userId),
      ),
      _loadSection<List<Map<String, dynamic>>>(
        "audit",
        () => _auditService.listForUser(userId),
      ),
      _loadSection<List<Map<String, dynamic>>>(
        "orders",
        () => _orderService.getOrdersWithItems(userId, includePending: true),
      ),
      _loadSection<List<Map<String, dynamic>>>(
        "addresses",
        () => _addressService.getAddresses(userId.toString()),
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _userDetails = (results[0] as Map<String, dynamic>?) ?? _userDetails;
      _access = (results[1] as List<Map<String, dynamic>>?) ?? _access;
      _accessLogs = (results[2] as List<Map<String, dynamic>>?) ?? _accessLogs;
      _orders = (results[3] as List<Map<String, dynamic>>?) ?? _orders;
      _addresses = (results[4] as List<Map<String, dynamic>>?) ?? _addresses;
      _loading = false;
      if (_userDetails.isEmpty &&
          _access.isEmpty &&
          _accessLogs.isEmpty &&
          _orders.isEmpty &&
          _addresses.isEmpty &&
          _sectionErrors.isNotEmpty) {
        _pageError = "Kullanıcı detay verileri yüklenemedi.";
      }
    });
  }

  Future<T?> _loadSection<T>(String key, Future<T> Function() loader) async {
    try {
      final result = await loader();
      _sectionErrors.remove(key);
      return result;
    } catch (error) {
      _sectionErrors[key] = ErrorManager.parseGraphQLError(error.toString());
      return null;
    }
  }

  Future<void> _removeAccess(Map<String, dynamic> item) async {
    final accessKey = item["id"]?.toString() ?? "";
    final actor = context.read<AuthProvider>().user;
    final itemTitle = item["item_title"]?.toString().trim().isNotEmpty == true
        ? item["item_title"].toString()
        : (item["item_type_label"]?.toString() ?? "Bu erişim");

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: const Text("Erişimi Kaldır"),
        content: SingleChildScrollView(
          child: Text(
            "$itemTitle erişimini kaldırmak istediğinize emin misiniz? Bu işlem kullanıcı tarafındaki erişimi pasife çevirir.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Kaldır", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingAccessKey = accessKey);
    try {
      await _adminService.deactivateAccessEntry(item);
      try {
        final auditUserId = _asInt(widget.user["id"]);
        if (auditUserId != null) {
          await _auditService.logEntry(
            userId: auditUserId,
            actorUserId: actor?.id,
            action: "deactivate",
            itemType: (item["item_type"] ?? "").toString(),
            itemId: _asInt(item["item_id"]),
            itemTitle: itemTitle,
            accessSource: item["source"]?.toString() ?? "user_content_access",
            previousExpiresAt: _parseDate(item["expires_at"]),
            newExpiresAt: null,
            note: "Admin paneli erişim kaldırma",
          );
        }
      } catch (_) {
        // Audit log migration'ı henüz uygulanmadıysa ana akışı bozma.
      }
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Erişim pasife çekildi.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erişim kaldırılamadı: $e")));
    } finally {
      if (mounted) setState(() => _removingAccessKey = null);
    }
  }

  Future<void> _reconcileRevenueCatSubscription() async {
    final userId = _asInt(widget.user["id"]);
    if (userId == null || _revenueCatReconcileLoading) return;

    setState(() {
      _revenueCatReconcileLoading = true;
      _revenueCatReconcileMessage = null;
      _revenueCatReconcileSuccess = null;
    });

    try {
      final result = await _adminService.reconcileRevenueCatSubscription(
        userId: userId,
      );
      await _loadAll();
      if (!mounted) return;

      final message = result["message"]?.toString().trim();
      final summary = message != null && message.isNotEmpty
          ? message
          : (result["fixed"] == true
                ? "Abonelik düzeltildi."
                : result["healthy"] == true || result["alreadySynced"] == true
                ? "Abonelik tarafında kullanıcının sorunu bulunmamaktadır."
                : "RevenueCat'te aktif abonelik bulunamadı.");
      final success =
          result["fixed"] == true ||
          result["healthy"] == true ||
          result["alreadySynced"] == true ||
          result["activeAccessAfter"] == true;

      setState(() {
        _revenueCatReconcileMessage = summary;
        _revenueCatReconcileSuccess = success;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      if (!mounted) return;
      final message = "Abonelik incelenemedi: $e";
      setState(() {
        _revenueCatReconcileMessage = message;
        _revenueCatReconcileSuccess = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _revenueCatReconcileLoading = false);
      }
    }
  }

  Future<void> _showPasswordUpdateDialog() async {
    final userId = _asInt(widget.user["id"]);
    if (userId == null || _passwordUpdateLoading) return;

    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var obscurePassword = true;
        var obscureConfirm = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> savePassword() async {
              if (!formKey.currentState!.validate()) return;

              setDialogState(() => _passwordUpdateLoading = true);
              try {
                final ok = await _adminService.updateUserPassword(
                  id: userId,
                  password: passwordCtrl.text,
                );
                if (!ok) {
                  throw Exception("Kullanıcı bulunamadı veya güncellenemedi.");
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Kullanıcı şifresi güncellendi."),
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      "Şifre güncellenemedi: "
                      "${ErrorManager.parseGraphQLError(error.toString())}",
                    ),
                  ),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => _passwordUpdateLoading = false);
                }
                if (mounted) {
                  setState(() {});
                }
              }
            }

            return AlertDialog(
              title: const Text("Kullanıcı Şifresini Değiştir"),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _displayValue(_resolvedUser["email"]),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Yeni şifre",
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword ? "Göster" : "Gizle",
                            onPressed: _passwordUpdateLoading
                                ? null
                                : () => setDialogState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: "Yeni şifre tekrar",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: obscureConfirm ? "Göster" : "Gizle",
                            onPressed: _passwordUpdateLoading
                                ? null
                                : () => setDialogState(
                                    () => obscureConfirm = !obscureConfirm,
                                  ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final confirm = value?.trim() ?? "";
                          if (confirm != passwordCtrl.text.trim()) {
                            return "Şifreler aynı olmalı.";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _passwordUpdateLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text("Vazgeç"),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _passwordUpdateLoading ? null : savePassword,
                  icon: _passwordUpdateLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _passwordUpdateLoading ? "Kaydediliyor..." : "Kaydet",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _validateNewPassword(String? value) {
    final password = value?.trim() ?? "";
    if (password.isEmpty) return "Yeni şifre zorunlu.";
    if (password.length < 8) return "En az 8 karakter olmalı.";
    if (!RegExp(r"[A-Z]").hasMatch(password)) {
      return "En az 1 büyük harf içermeli.";
    }
    if (!RegExp(r"[a-z]").hasMatch(password)) {
      return "En az 1 küçük harf içermeli.";
    }
    if (!RegExp(r"[0-9]").hasMatch(password)) {
      return "En az 1 rakam içermeli.";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = _resolvedUser;
    final visibleOrders = _buildVisibleOrders();
    final orderStats = _buildOrderStats();
    final totalPaid = (orderStats["totalPaid"] as num?)?.toDouble() ?? 0;
    final activeCount = _access.where(_isAccessCurrentlyActive).length;
    final passiveCount = _access.length - activeCount;
    final filteredAccess = _buildFilteredAccess();
    final contentSummary = _buildContentSummary(filteredAccess);

    return Scaffold(
      appBar: AppBar(
        title: Text("${user["name"] ?? "Kullanıcı"} Detay"),
        actions: [
          IconButton(
            tooltip: "Yenile",
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const AdminLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_pageError != null) ...[
                  _messageCard(
                    _pageError!,
                    color: const Color(0xFFB71C1C),
                    backgroundColor: const Color(0xFFFFEBEE),
                  ),
                  const SizedBox(height: 18),
                ],
                if (_sectionErrors.isNotEmpty) ...[
                  _sectionTitle("Yükleme Uyarıları"),
                  _infoCard([
                    for (final entry in _sectionErrors.entries)
                      _infoRow(
                        _sectionLabel(entry.key),
                        entry.value,
                        labelWidth: 130,
                        multiLine: true,
                      ),
                  ]),
                  const SizedBox(height: 18),
                ],
                _sectionTitle("Kullanıcı Bilgileri"),
                _infoCard([
                  _infoRow("ID", user["id"]?.toString() ?? "-"),
                  _infoRow("Ad Soyad", user["name"] ?? "-"),
                  _infoRow("E-posta", user["email"] ?? "-"),
                  _infoRow("Telefon", user["phone"] ?? "-"),
                  _infoRow("Rol", _roleLabel(user)),
                  _infoRow("Durum", _userActiveLabel(user)),
                  if (user["deactivated_at"] != null ||
                      user["is_active"] == false)
                    _infoRow("Pasife Alınma", _deactivationLabel(user)),
                  _infoRow("E-posta Onayı", _emailVerificationLabel(user)),
                  _infoRow("Pay ID", _displayValue(user["payUniqe"])),
                  _infoRow("Avatar", _displayValue(user["avatar_url"])),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _passwordUpdateLoading
                          ? null
                          : _showPasswordUpdateDialog,
                      icon: const Icon(Icons.lock_reset),
                      label: const Text("Şifre Değiştir"),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _sectionTitle("Abonelikler"),
                _infoCard([
                  _infoRow("Toplam", _access.length.toString()),
                  _infoRow("Aktif", activeCount.toString()),
                  _infoRow("Pasif", passiveCount.toString()),
                ]),
                const SizedBox(height: 12),
                _infoCard([
                  const Text(
                    "RevenueCat'te aktif abonelik varsa ve sistemde eksikse tek tuşla düzeltir.",
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _revenueCatReconcileLoading
                          ? null
                          : _reconcileRevenueCatSubscription,
                      icon: _revenueCatReconcileLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.manage_search),
                      label: Text(
                        _revenueCatReconcileLoading
                            ? "Taranıyor..."
                            : "Aboneliği Tara ve Düzelt",
                      ),
                    ),
                  ),
                ]),
                if (_revenueCatReconcileMessage != null) ...[
                  const SizedBox(height: 12),
                  _messageCard(
                    _revenueCatReconcileMessage!,
                    color: _revenueCatReconcileSuccess == true
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF37474F),
                    backgroundColor: _revenueCatReconcileSuccess == true
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFECEFF1),
                  ),
                ],
                const SizedBox(height: 12),
                _sectionTitle("Erişim Filtreleri"),
                _infoCard([
                  _filterWrap<_AccessStatusFilter>(
                    label: "Durum",
                    current: _statusFilter,
                    options: const [
                      (_AccessStatusFilter.all, "Tümü"),
                      (_AccessStatusFilter.active, "Sadece Aktifler"),
                      (_AccessStatusFilter.passive, "Sadece Pasifler"),
                    ],
                    onSelected: (value) {
                      setState(() => _statusFilter = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _filterWrap<_AccessTypeFilter>(
                    label: "Tür",
                    current: _typeFilter,
                    options: const [
                      (_AccessTypeFilter.all, "Tümü"),
                      (_AccessTypeFilter.book, "Kitap"),
                      (_AccessTypeFilter.magazine, "Dergi"),
                      (_AccessTypeFilter.newspaper, "Gazete"),
                    ],
                    onSelected: (value) {
                      setState(() => _typeFilter = value);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                _sectionTitle("İçerik Özeti"),
                _listCard(
                  emptyText: "İçerik özeti bulunamadı.",
                  items: contentSummary,
                  itemBuilder: (item) {
                    final names = (item["names"] as List<String>? ?? const [])
                        .where((value) => value.trim().isNotEmpty)
                        .toList(growable: false);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item["title"]?.toString() ?? "-"),
                      subtitle: Text(
                        names.isEmpty ? "-" : names.join(", "),
                        style: const TextStyle(height: 1.45),
                      ),
                      trailing: Text(
                        "${item["count"] ?? 0}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: _access.isEmpty
                      ? "Abonelik bulunamadı."
                      : "Seçili filtreye uygun erişim bulunamadı.",
                  items: filteredAccess,
                  itemBuilder: (item) {
                    final type =
                        item["item_type_label"]?.toString() ??
                        _accessTypeLabel((item["item_type"] ?? "").toString());
                    final itemId = item["item_id"]?.toString() ?? "-";
                    final itemTitle =
                        item["item_title"]?.toString().trim().isNotEmpty == true
                        ? item["item_title"].toString()
                        : type;
                    final itemSubtitle = item["item_subtitle"]
                        ?.toString()
                        .trim();
                    final periodLabel = _accessPeriodLabel(item);
                    final started = _formatDateShort(item["started_at"]);
                    final expires = _formatDateShort(item["expires_at"]);
                    final status = _accessStatus(item);
                    final price = _formatPrice(item["purchase_price"]);
                    final channelLabel =
                        item["access_channel_label"]
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true
                        ? item["access_channel_label"].toString()
                        : PurchaseChannelLabels.accessChannelLabel(item);
                    final accessKey = item["id"]?.toString() ?? "";
                    final canRemove = item["is_active"] == true;
                    final isRemoving = _removingAccessKey == accessKey;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(itemTitle),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              type,
                              if (itemSubtitle != null &&
                                  itemSubtitle.isNotEmpty)
                                itemSubtitle,
                              if (periodLabel != null && periodLabel.isNotEmpty)
                                "Süre: $periodLabel",
                              if (price != null) "Tutar: $price",
                            ].join("  •  "),
                          ),
                          const SizedBox(height: 4),
                          Text("Başlangıç: $started  •  Bitiş: $expires"),
                          if (channelLabel != "Bilinmiyor") ...[
                            const SizedBox(height: 4),
                            Text("Kaynak: $channelLabel"),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "ID: $itemId",
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: status.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (isRemoving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (canRemove)
                            InkWell(
                              onTap: () => _removeAccess(item),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _sectionTitle("Erişim Hareketleri"),
                _listCard(
                  emptyText: "Henüz erişim hareketi bulunmuyor.",
                  items: _accessLogs,
                  itemBuilder: (item) {
                    final created = _formatDateShort(item["created_at"]);
                    final actor = item["actor"] as Map<String, dynamic>?;
                    final actorLabel =
                        actor?["name"]?.toString().trim().isNotEmpty == true
                        ? actor!["name"].toString()
                        : "Yönetici";
                    final title =
                        item["item_title"]?.toString().trim().isNotEmpty == true
                        ? item["item_title"].toString()
                        : _accessTypeLabel(
                            (item["item_type"] ?? "").toString(),
                          );
                    final previous = _formatDateShort(
                      item["previous_expires_at"],
                    );
                    final next = _formatDateShort(item["new_expires_at"]);
                    final note = item["note"]?.toString().trim();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_auditActionLabel(item)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              title,
                              "Tarih: $created",
                              "İşlemi yapan: $actorLabel",
                            ].join("  •  "),
                          ),
                          if (item["previous_expires_at"] != null ||
                              item["new_expires_at"] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Önceki bitiş: $previous  •  Yeni bitiş: $next",
                            ),
                          ],
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(note),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _sectionTitle("Siparişler"),
                _infoCard([
                  _infoRow("Toplam", orderStats["total"].toString()),
                  _infoRow("Tamamlanan", orderStats["completed"].toString()),
                  _infoRow("Bekleyen", orderStats["pending"].toString()),
                  _infoRow("İptal/İade", orderStats["failed"].toString()),
                  _infoRow("Toplam Tutar", "₺${totalPaid.toStringAsFixed(2)}"),
                ]),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: "Sipariş bulunamadı.",
                  items: visibleOrders,
                  itemBuilder: (order) {
                    final id = order["id"]?.toString() ?? "-";
                    final total = order["total_paid"]?.toString() ?? "0";
                    final created = _formatDateShort(order["created_at"]);
                    final items = (order["order_items"] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();
                    final statusLabel = _statusLabel(
                      (order["status"] ?? "paid").toString(),
                    );
                    final paymentChannel =
                        PurchaseChannelLabels.orderChannelLabel(order);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(child: Text("Sipariş #$id")),
                          const SizedBox(width: 8),
                          _statusChip(statusLabel),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tarih: $created  •  Toplam: ₺$total"),
                          const SizedBox(height: 4),
                          Text("Ödeme Kanalı: $paymentChannel"),
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...items.map((it) {
                              final title = it["title"]?.toString() ?? "-";
                              final qty = it["quantity"]?.toString() ?? "1";
                              final line =
                                  it["line_total"]?.toString() ??
                                  it["unit_price"]?.toString() ??
                                  "-";
                              final type = (it["product_type"] ?? "")
                                  .toString()
                                  .trim();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 48,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDEDED),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: orderItemThumbnail(
                                        it,
                                        width: 36,
                                        height: 48,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "• $title x$qty (₺$line)${type.isNotEmpty ? " • ${_orderItemTypeLabel(type)}" : ""}",
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _sectionTitle("Adresler"),
                _infoCard([_infoRow("Toplam", _addresses.length.toString())]),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: "Adres bulunamadı.",
                  items: _addresses,
                  itemBuilder: (a) {
                    final name = a["address_name"] ?? "-";
                    final type =
                        (a["address_type"] ?? "").toString().toLowerCase() ==
                            "kurumsal"
                        ? "Kurumsal"
                        : "Bireysel";
                    final full = a["full_address"] ?? "-";
                    final tax = (a["tax_address"] ?? "").toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("$name ($type)"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(full),
                          if (tax.isNotEmpty) Text("Vergi Adresi: $tax"),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _listCard({
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic> item) itemBuilder,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: items.isEmpty
          ? Padding(padding: const EdgeInsets.all(8.0), child: Text(emptyText))
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  itemBuilder(items[i]),
                  if (i != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  Map<String, dynamic> get _resolvedUser => {...widget.user, ..._userDetails};

  Widget _messageCard(
    String text, {
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _filterWrap<T>({
    required String label,
    required T current,
    required List<(T, String)> options,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(option.$2),
                  selected: current == option.$1,
                  onSelected: (_) => onSelected(option.$1),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    double labelWidth = 110,
    bool multiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: multiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _accessTypeLabel(String type) {
    return AdminUserDetailMetrics.accessTypeLabel(type);
  }

  List<Map<String, dynamic>> _buildFilteredAccess() {
    return _access
        .where((item) {
          switch (_statusFilter) {
            case _AccessStatusFilter.active:
              if (!_isAccessCurrentlyActive(item)) return false;
              break;
            case _AccessStatusFilter.passive:
              if (_isAccessCurrentlyActive(item)) return false;
              break;
            case _AccessStatusFilter.all:
              break;
          }

          final itemType = (item["item_type"] ?? "").toString();
          switch (_typeFilter) {
            case _AccessTypeFilter.book:
              return itemType == "book";
            case _AccessTypeFilter.magazine:
              return itemType == "magazine" || itemType == "magazine_issue";
            case _AccessTypeFilter.newspaper:
              return itemType == "newspaper_subscription";
            case _AccessTypeFilter.all:
              return true;
          }
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildContentSummary(
    List<Map<String, dynamic>> access,
  ) {
    return AdminUserDetailMetrics.buildContentSummary(access);
  }

  List<Map<String, dynamic>> _buildVisibleOrders() {
    return AdminUserDetailMetrics.buildVisibleOrders(_orders);
  }

  Map<String, dynamic> _buildOrderStats() {
    return AdminUserDetailMetrics.buildOrderStats(_orders);
  }

  String? _accessPeriodLabel(Map<String, dynamic> item) {
    return AdminUserDetailMetrics.accessPeriodLabel(item);
  }

  bool _isAccessCurrentlyActive(Map<String, dynamic> item) {
    if (item["is_active"] != true) return false;
    final expiresAt = _parseDate(item["expires_at"]);
    if (expiresAt == null) return true;
    return expiresAt.isAfter(DateTime.now());
  }

  _AccessStatus _accessStatus(Map<String, dynamic> item) {
    if (item["is_active"] != true) {
      return const _AccessStatus("Pasif", Colors.grey);
    }
    final expiresAt = _parseDate(item["expires_at"]);
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      return const _AccessStatus("Süresi Dolmuş", Colors.orange);
    }
    return const _AccessStatus("Aktif", Colors.green);
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return "Beklemede";
      case "paid":
        return "Ödendi";
      case "success":
        return "Başarılı";
      case "completed":
        return "Tamamlandı";
      case "shipped":
        return "Kargoda";
      case "delivered":
        return "Teslim Edildi";
      case "canceled":
        return "İptal";
      case "refunded":
        return "İade";
      default:
        return status;
    }
  }

  String _orderItemTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case "book":
        return "Kitap";
      case "magazine":
        return "Dergi";
      case "magazine_issue":
        return "Dergi Sayısı";
      case "newspaper":
      case "newspaper_subscription":
        return "E-Gazete";
      case "supplement":
      case "ek":
        return "Ek";
      default:
        return type;
    }
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    final color = switch (lower) {
      "ödendi" => Colors.green,
      "başarılı" => Colors.green,
      "tamamlandı" => Colors.green,
      "teslim edildi" => Colors.green,
      "beklemede" => Colors.orange,
      "iptal" => Colors.red,
      "iade" => Colors.deepOrange,
      "kargoda" => Colors.blue,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String? _formatPrice(dynamic raw) {
    if (raw == null) return null;
    final parsed = double.tryParse(raw.toString());
    if (parsed == null) return null;
    return "₺${parsed.toStringAsFixed(2)}";
  }

  String _formatDateShort(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return "-";
    return text;
  }

  String _roleLabel(Map<String, dynamic> user) {
    final role = user["role"];
    if (role is Map<String, dynamic>) {
      return _displayValue(role["name"]);
    }
    return _displayValue(role);
  }

  String _userActiveLabel(Map<String, dynamic> user) {
    final isActive = user["is_active"];
    if (isActive == null) return "-";
    return isActive == true ? "Aktif" : "Pasif";
  }

  String _emailVerificationLabel(Map<String, dynamic> user) {
    final verifiedAt = user["email_verified_at"];
    if (verifiedAt == null || verifiedAt.toString().trim().isEmpty) {
      return "Doğrulanmamış";
    }
    return _formatDateShort(verifiedAt);
  }

  String _deactivationLabel(Map<String, dynamic> user) {
    final deactivatedAt = user["deactivated_at"];
    if (deactivatedAt == null || deactivatedAt.toString().trim().isEmpty) {
      return "Pasife alınma tarihi bulunamadı";
    }
    return _formatDateShort(deactivatedAt);
  }

  String _sectionLabel(String key) {
    switch (key) {
      case "user":
        return "Kullanıcı";
      case "access":
        return "Erişimler";
      case "audit":
        return "Erişim Hareketleri";
      case "orders":
        return "Siparişler";
      case "addresses":
        return "Adresler";
      default:
        return key;
    }
  }

  String _auditActionLabel(Map<String, dynamic> item) {
    final action = (item["action"] ?? "").toString().toLowerCase();
    switch (action) {
      case "extend":
        return "Abonelik Uzatıldı";
      case "deactivate":
        return "Erişim Pasife Çekildi";
      case "grant":
        return "Erişim Tanımlandı";
      default:
        return "Erişim Hareketi";
    }
  }
}

class _AccessStatus {
  final String label;
  final Color color;

  const _AccessStatus(this.label, this.color);
}

enum _AccessStatusFilter { all, active, passive }

enum _AccessTypeFilter { all, book, magazine, newspaper }
