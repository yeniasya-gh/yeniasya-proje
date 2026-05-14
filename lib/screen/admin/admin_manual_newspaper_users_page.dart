import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/admin/admin_manual_newspaper_user_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/loading_manager.dart';
import 'admin_loading_indicator.dart';

class AdminManualNewspaperUsersPage extends StatefulWidget {
  const AdminManualNewspaperUsersPage({super.key});

  @override
  State<AdminManualNewspaperUsersPage> createState() =>
      _AdminManualNewspaperUsersPageState();
}

class _AdminManualNewspaperUsersPageState
    extends State<AdminManualNewspaperUsersPage> {
  final _service = AdminManualNewspaperUserService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];
  int _totalCount = 0;
  int _currentPage = 1;
  int _pageSize = 20;
  String _currentSearch = "";
  String _statusFilter = "all";
  String _activeFilter = "all";
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _loadPage(
      page: _currentPage,
      search: _searchCtrl.text,
      status: _statusFilter,
      activeState: _activeFilter,
      pageSize: _pageSize,
    );
  }

  Future<void> _loadPage({
    required int page,
    required String search,
    required String status,
    required String activeState,
    required int pageSize,
  }) async {
    final requestSeq = ++_requestSeq;
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 20 : pageSize;

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final result = await _service.listManualUsersPage(
        keyword: search,
        status: status,
        activeState: activeState,
        page: safePage,
        pageSize: safePageSize,
      );
      final totalPages = result.totalCount <= 0
          ? 1
          : ((result.totalCount + safePageSize - 1) ~/ safePageSize);
      if (safePage > totalPages && result.totalCount > 0) {
        await _loadPage(
          page: totalPages,
          search: search,
          status: status,
          activeState: activeState,
          pageSize: safePageSize,
        );
        return;
      }
      if (!mounted || requestSeq != _requestSeq) return;
      setState(() {
        _items = result.items;
        _totalCount = result.totalCount;
        _currentPage = safePage > totalPages ? totalPages : safePage;
        _currentSearch = search.trim();
        _statusFilter = status;
        _activeFilter = activeState;
        _pageSize = safePageSize;
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted && requestSeq == _requestSeq) {
        setState(() => _loading = false);
      }
    }
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadPage(
        page: 1,
        search: value,
        status: _statusFilter,
        activeState: _activeFilter,
        pageSize: _pageSize,
      );
    });
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final rootContext = context;
    final userMap = Map<String, dynamic>.from(initial?["user"] ?? const {});
    Map<String, dynamic>? selectedUser = userMap.isEmpty
        ? null
        : Map<String, dynamic>.from(userMap);
    DateTime startsAt = _parseDate(initial?["starts_at"]) ?? DateTime.now();
    DateTime endsAt =
        _parseDate(initial?["ends_at"]) ??
        DateTime.now().add(const Duration(days: 30));
    bool isActive = initial?["is_active"] as bool? ?? true;
    String status =
        (initial?["status"]?.toString().trim().toLowerCase() ?? "new")
            .replaceAll("eski", "old");
    if (status != "old") {
      status = "new";
    }
    final noteCtrl = TextEditingController(
      text: initial?["note"]?.toString() ?? "",
    );
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> userResults = [];
    bool searchingUsers = false;
    int searchRequestSeq = 0;

    if (initial == null) {
      try {
        userResults = await _service.searchUsers(keyword: "", limit: 20);
      } catch (_) {
        userResults = [];
      }
    }

    Future<void> searchUsers(StateSetter setSheetState, String keyword) async {
      final requestSeq = ++searchRequestSeq;
      setSheetState(() => searchingUsers = true);
      try {
        final found = await _service.searchUsers(keyword: keyword, limit: 20);
        if (!mounted || requestSeq != searchRequestSeq) return;
        setSheetState(() => userResults = found);
      } catch (e) {
        final parsed = ErrorManager.parseGraphQLError(e.toString());
        if (mounted && rootContext.mounted) {
          ScaffoldMessenger.of(
            rootContext,
          ).showSnackBar(SnackBar(content: Text(parsed)));
        }
      } finally {
        if (mounted && requestSeq == searchRequestSeq) {
          setSheetState(() => searchingUsers = false);
        }
      }
    }

    Future<void> pickDate(
      BuildContext sheetContext,
      StateSetter setSheetState, {
      required bool forStart,
    }) async {
      final current = forStart ? startsAt : endsAt;
      final picked = await showDatePicker(
        context: sheetContext,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      final value = DateTime(
        picked.year,
        picked.month,
        picked.day,
        forStart ? 0 : 23,
        forStart ? 0 : 59,
        forStart ? 0 : 59,
      );
      setSheetState(() {
        if (forStart) {
          startsAt = value;
          if (!endsAt.isAfter(startsAt)) {
            endsAt = startsAt.add(const Duration(days: 1));
          }
        } else {
          endsAt = value;
        }
      });
    }

    if (!mounted || !rootContext.mounted) return;

    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final canEditUser = initial == null;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        initial == null
                            ? "Manuel E-Gazete Kullanıcısı Ekle"
                            : "Manuel E-Gazete Kaydını Düzenle",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (canEditUser) ...[
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: "Kullanıcı ara (ad / e-posta)",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => searchUsers(setSheetState, value),
                    ),
                    const SizedBox(height: 8),
                    if (searchingUsers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    SizedBox(
                      height: 180,
                      child: userResults.isEmpty
                          ? const Center(
                              child: Text("Kullanıcı sonucu bulunamadı"),
                            )
                          : ListView.separated(
                              itemCount: userResults.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final u = userResults[i];
                                final selected = selectedUser?["id"] == u["id"];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.person_outline,
                                    color: selected
                                        ? Colors.green
                                        : Colors.black54,
                                  ),
                                  title: Text(u["name"]?.toString() ?? "-"),
                                  subtitle: Text(u["email"]?.toString() ?? "-"),
                                  onTap: () => setSheetState(
                                    () => selectedUser =
                                        Map<String, dynamic>.from(u),
                                  ),
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${selectedUser?["name"] ?? "-"} • ${selectedUser?["email"] ?? "-"}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(
                            sheetContext,
                            setSheetState,
                            forStart: true,
                          ),
                          icon: const Icon(Icons.calendar_month),
                          label: Text("Başlangıç: ${_formatDate(startsAt)}"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickDate(
                            sheetContext,
                            setSheetState,
                            forStart: false,
                          ),
                          icon: const Icon(Icons.event_available),
                          label: Text("Bitiş: ${_formatDate(endsAt)}"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Aktif"),
                    subtitle: const Text("Pasif yapılırsa erişim kapanır"),
                    value: isActive,
                    onChanged: (v) => setSheetState(() => isActive = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: "Kayıt Tipi",
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "new",
                        child: Text("Yeni (admin)"),
                      ),
                      DropdownMenuItem(
                        value: "old",
                        child: Text("Eski (import)"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Not (opsiyonel)",
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final userId = _toInt(selectedUser?["id"]);
                        if (userId == null) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(
                              content: Text("Lütfen kullanıcı seçin."),
                            ),
                          );
                          return;
                        }
                        if (!endsAt.isAfter(startsAt)) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Bitiş tarihi başlangıç tarihinden sonra olmalı.",
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(sheetContext);
                        setState(() => _saving = true);
                        try {
                          await _service.upsertManualUser(
                            userId: userId,
                            startsAt: startsAt,
                            endsAt: endsAt,
                            isActive: isActive,
                            status: status,
                            note: noteCtrl.text,
                          );
                          await _load();
                          if (mounted && rootContext.mounted) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Manuel e-gazete erişimi kaydedildi.",
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          final parsed = ErrorManager.parseGraphQLError(
                            e.toString(),
                          );
                          if (mounted && rootContext.mounted) {
                            ScaffoldMessenger.of(
                              rootContext,
                            ).showSnackBar(SnackBar(content: Text(parsed)));
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                      child: const Text("Kaydet"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    final id = _toInt(item["id"]);
    if (id == null) return;
    final current = item["is_active"] == true;
    setState(() => _saving = true);
    try {
      await _service.updateById(id: id, isActive: !current);
      await _load();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = _toInt(item["id"]);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kaydı Sil"),
        content: const Text("Bu manuel e-gazete kaydı silinsin mi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await _service.deleteById(id);
      await _load();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Manuel E-Gazete Kullanıcılar",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text("Kullanıcı Ekle"),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              onChanged: _scheduleSearch,
              decoration: InputDecoration(
                hintText: "İsim, e-posta, not veya kullanıcı id ara...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _activeFilter,
                    decoration: InputDecoration(
                      labelText: "Erişim Durumu",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Tümü")),
                      DropdownMenuItem(value: "active", child: Text("Aktif")),
                      DropdownMenuItem(value: "inactive", child: Text("Pasif")),
                      DropdownMenuItem(
                        value: "expired",
                        child: Text("Süresi Doldu"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _activeFilter = value);
                      _loadPage(
                        page: 1,
                        search: _searchCtrl.text,
                        status: _statusFilter,
                        activeState: value,
                        pageSize: _pageSize,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: InputDecoration(
                      labelText: "Kayıt Tipi",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Tümü")),
                      DropdownMenuItem(value: "new", child: Text("Yeni")),
                      DropdownMenuItem(value: "old", child: Text("Eski")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _statusFilter = value);
                      _loadPage(
                        page: 1,
                        search: _searchCtrl.text,
                        status: value,
                        activeState: _activeFilter,
                        pageSize: _pageSize,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                    value: _pageSize,
                    decoration: InputDecoration(
                      labelText: "Sayfa Boyutu",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text("10")),
                      DropdownMenuItem(value: 20, child: Text("20")),
                      DropdownMenuItem(value: 50, child: Text("50")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _pageSize = value);
                      _loadPage(
                        page: 1,
                        search: _searchCtrl.text,
                        status: _statusFilter,
                        activeState: _activeFilter,
                        pageSize: value,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const AdminLoadingIndicator()
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        "Henüz manuel e-gazete kullanıcısı eklenmedi.",
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final user = Map<String, dynamic>.from(
                          item["user"] ?? const {},
                        );
                        final startsAt = _parseDate(item["starts_at"]);
                        final endsAt = _parseDate(item["ends_at"]);
                        final isActive = item["is_active"] == true;
                        final note = (item["note"] ?? "").toString().trim();
                        final recordStatus = _statusLabel(
                          (item["status"] ?? "new").toString(),
                        );
                        final now = DateTime.now();
                        final expired = endsAt == null
                            ? false
                            : !endsAt.isAfter(now);
                        final statusText = !isActive
                            ? "Pasif"
                            : (expired ? "Süresi Doldu" : "Aktif");
                        final statusColor = !isActive
                            ? Colors.grey
                            : (expired ? Colors.orange : Colors.green);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user["name"]?.toString() ??
                                              "Kullanıcı #${item["user_id"]}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user["email"]?.toString() ?? "-",
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _statusChip(recordStatus),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    "Başlangıç: ${startsAt == null ? "-" : _formatDateTime(startsAt)}",
                                  ),
                                  Text(
                                    "Bitiş: ${endsAt == null ? "-" : _formatDateTime(endsAt)}",
                                  ),
                                ],
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "Not: $note",
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _openEditor(initial: item),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text("Düzenle"),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _toggleActive(item),
                                    icon: Icon(
                                      isActive
                                          ? Icons.pause_circle_outline
                                          : Icons.play_circle_outline,
                                    ),
                                    label: Text(
                                      isActive ? "Pasife Al" : "Aktifleştir",
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Sil",
                                    onPressed: () => _deleteItem(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Toplam $_totalCount kayıt${_currentSearch.isNotEmpty ? " • Arama: $_currentSearch" : ""} • Durum: ${_filterLabel(_activeFilter)} • Tip: ${_statusLabel(_statusFilter)} • Sayfa $_currentPage / ${_totalPages()}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: (_currentPage <= 1 || _loading)
                          ? null
                          : () => _loadPage(
                                page: _currentPage - 1,
                                search: _searchCtrl.text,
                                status: _statusFilter,
                                activeState: _activeFilter,
                                pageSize: _pageSize,
                              ),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text("Önceki"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: (_currentPage >= _totalPages() || _loading)
                          ? null
                          : () => _loadPage(
                                page: _currentPage + 1,
                                search: _searchCtrl.text,
                                status: _statusFilter,
                                activeState: _activeFilter,
                                pageSize: _pageSize,
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
        AnimatedBuilder(
          animation: LoadingManager.instance,
          builder: (_, __) {
            if (!_saving || LoadingManager.instance.loading) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          },
        ),
      ],
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == "old" || normalized == "eski") return "Eski";
    return "Yeni";
  }

  String _filterLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case "active":
        return "Aktif";
      case "inactive":
        return "Pasif";
      case "expired":
        return "Süresi Doldu";
      default:
        return "Tümü";
    }
  }

  int _totalPages() {
    if (_totalCount <= 0) return 1;
    return ((_totalCount + _pageSize - 1) ~/ _pageSize);
  }

  Widget _statusChip(String label) {
    final isOld = label == "Eski";
    final color = isOld ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return "$d.$m.$y";
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "$d.$m.$y $hh:$mm";
  }
}
