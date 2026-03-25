import 'package:flutter/material.dart';

import '../../services/admin/admin_user_access_audit_service.dart';
import '../../services/admin/admin_user_service.dart';
import '../../services/error/error_manager.dart';
import 'admin_loading_indicator.dart';
import 'admin_user_detail_page.dart';

class AdminPassiveUsersPage extends StatefulWidget {
  final AdminUserService? adminService;
  final AdminUserAccessAuditService? auditService;

  const AdminPassiveUsersPage({
    super.key,
    this.adminService,
    this.auditService,
  });

  @override
  State<AdminPassiveUsersPage> createState() => _AdminPassiveUsersPageState();
}

class _AdminPassiveUsersPageState extends State<AdminPassiveUsersPage> {
  late final AdminUserService _adminService;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _pageError;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _adminService = widget.adminService ?? AdminUserService();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _pageError = null;
      });
    }

    try {
      final users = await _adminService.getPassiveUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _filtered = _filterUsers(users, _searchCtrl.text);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageError = ErrorManager.parseGraphQLError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filter(String text) {
    setState(() {
      _filtered = _filterUsers(_users, text);
    });
  }

  List<Map<String, dynamic>> _filterUsers(
    List<Map<String, dynamic>> users,
    String text,
  ) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return List<Map<String, dynamic>>.from(users);
    return users
        .where((u) {
          final name = (u["name"] ?? "").toString().toLowerCase();
          final email = (u["email"] ?? "").toString().toLowerCase();
          final role = (u["role"] ?? "").toString().toLowerCase();
          final deactivatedAt = _formatDateShort(
            u["deactivated_at"],
          ).toLowerCase();
          return name.contains(query) ||
              email.contains(query) ||
              role.contains(query) ||
              deactivatedAt.contains(query);
        })
        .toList(growable: false);
  }

  void _openUserDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserDetailPage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pasif Kullanıcılar"),
        actions: [
          IconButton(
            tooltip: "Yenile",
            onPressed: _loading ? null : _loadUsers,
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
                _sectionTitle("Özet"),
                _infoCard([
                  _infoRow("Filtrelenen", _filtered.length.toString()),
                  _infoRow("Toplam Pasif", _users.length.toString()),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Ad, e-posta, rol veya tarih ara",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _listCard(
                  items: _filtered,
                  emptyText: _users.isEmpty
                      ? "Pasif kullanıcı bulunamadı."
                      : "Seçili filtreye uygun pasif kullanıcı bulunamadı.",
                  itemBuilder: (user) {
                    final name = _displayValue(user["name"]);
                    final email = _displayValue(user["email"]);
                    final role = _displayValue(user["role"]);
                    final deactivatedAt = _formatDateShort(
                      user["deactivated_at"],
                    );
                    final verifiedAt = _formatDateShort(
                      user["email_verified_at"],
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("E-posta: $email"),
                          const SizedBox(height: 4),
                          Text("Rol: $role  •  Pasife alınma: $deactivatedAt"),
                          const SizedBox(height: 4),
                          Text("E-posta onayı: $verifiedAt"),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: "Detay",
                        icon: const Icon(Icons.open_in_new, color: Colors.blue),
                        onPressed: () => _openUserDetail(user),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _messageCard(
    String text, {
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
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

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String value, {double labelWidth = 120}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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

  Widget _listCard({
    required List<Map<String, dynamic>> items,
    required String emptyText,
    required Widget Function(Map<String, dynamic> item) itemBuilder,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(emptyText)),
            )
          : Column(
              children: [
                for (final item in items) ...[
                  itemBuilder(item),
                  if (item != items.last) const Divider(height: 24),
                ],
              ],
            ),
    );
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return "-";
    return text;
  }

  String _formatDateShort(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }
}
