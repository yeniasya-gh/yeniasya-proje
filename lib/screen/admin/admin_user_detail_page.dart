import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/address_service.dart';
import '../../services/admin/admin_user_access_audit_service.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/order_service.dart';
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
        () => _orderService.getOrdersWithItems(userId),
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
        title: const Text("Erişimi Kaldır"),
        content: Text(
          "$itemTitle erişimini kaldırmak istediğinize emin misiniz? Bu işlem kullanıcı tarafındaki erişimi pasife çevirir.",
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
        await _auditService.logEntry(
          userId: widget.user["id"] as int,
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

  @override
  Widget build(BuildContext context) {
    final user = _resolvedUser;
    final paidOrders = _orders
        .where((o) => (o["status"] ?? "").toString().toLowerCase() == "paid")
        .toList();
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
                  _infoRow("E-posta Onayı", _emailVerificationLabel(user)),
                  _infoRow("Pay ID", _displayValue(user["payUniqe"])),
                  _infoRow("Avatar", _displayValue(user["avatar_url"])),
                ]),
                const SizedBox(height: 18),
                _sectionTitle("Abonelikler"),
                _infoCard([
                  _infoRow("Toplam", _access.length.toString()),
                  _infoRow("Aktif", activeCount.toString()),
                  _infoRow("Pasif", passiveCount.toString()),
                ]),
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
                        item["count"]?.toString() ?? "0",
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
                    final started = _formatDateShort(item["started_at"]);
                    final expires = _formatDateShort(item["expires_at"]);
                    final status = _accessStatus(item);
                    final price = _formatPrice(item["purchase_price"]);
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
                              if (price != null) "Tutar: $price",
                            ].join("  •  "),
                          ),
                          const SizedBox(height: 4),
                          Text("Başlangıç: $started  •  Bitiş: $expires"),
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
                _sectionTitle("Başarılı Siparişler"),
                _infoCard([_infoRow("Toplam", paidOrders.length.toString())]),
                const SizedBox(height: 8),
                _listCard(
                  emptyText: "Başarılı sipariş bulunamadı.",
                  items: paidOrders,
                  itemBuilder: (order) {
                    final id = order["id"]?.toString() ?? "-";
                    final total = order["total_paid"]?.toString() ?? "0";
                    final created = _formatDateShort(order["created_at"]);
                    final items = (order["order_items"] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Sipariş #$id"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tarih: $created  •  Toplam: ₺$total"),
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...items.map((it) {
                              final title = it["title"]?.toString() ?? "-";
                              final qty = it["quantity"]?.toString() ?? "1";
                              final line =
                                  it["line_total"]?.toString() ??
                                  it["unit_price"]?.toString() ??
                                  "-";
                              return Text("• $title x$qty (₺$line)");
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
    switch (type) {
      case "book":
        return "Kitap";
      case "magazine":
        return "E-dergi";
      case "magazine_issue":
        return "Dergi Sayısı";
      case "newspaper_subscription":
        return "Gazete Aboneliği";
      case "ek":
        return "Ek";
      default:
        return type;
    }
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
    final grouped = <String, Map<String, dynamic>>{};

    for (final item in access) {
      final type =
          item["item_type_label"]?.toString() ??
          _accessTypeLabel((item["item_type"] ?? "").toString());
      final name = item["item_title"]?.toString().trim().isNotEmpty == true
          ? item["item_title"].toString().trim()
          : type;
      final key = type;
      final group = grouped.putIfAbsent(
        key,
        () => {"title": type, "names": <String>{}},
      );
      (group["names"] as Set<String>).add(name);
    }

    final summary = grouped.values
        .map(
          (group) => {
            "title": group["title"],
            "names": ((group["names"] as Set<String>).toList()..sort()),
            "count": (group["names"] as Set<String>).length,
          },
        )
        .toList(growable: false);
    summary.sort(
      (a, b) => (a["title"]?.toString() ?? "").compareTo(
        b["title"]?.toString() ?? "",
      ),
    );
    return summary;
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
