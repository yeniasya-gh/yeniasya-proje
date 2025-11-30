import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/access_provider.dart';
import '../../services/user_content_access_service.dart';
import '../../utils/route_guard.dart';
import '../address/address_list_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../order/order_list_screen.dart';
import 'pdf_viewer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _accessService = UserContentAccessService();
  final _bookService = AdminBookService();
  final _magService = AdminMagazineService();

  bool _loadingAccess = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.name ?? "Kullanıcı Adı";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "Profil",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundImage: AssetImage("assets/images/avatar.png"),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    auth.user?.email ?? "",
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      auth.user?.isAdmin == true ? "Admin" : "Üye",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Abonelikler / İçerikler",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _subscriptionCard(auth),
            if (kIsWeb && auth.user?.isAdmin == true) ...[
              const SizedBox(height: 20),
              _menuCard(
                items: [
                  _menuTile(
                    Icons.admin_panel_settings,
                    "Yönetim Paneli",
                    onTap: () {
                      Navigator.push(
                        context,
                        RouteGuard.guard(
                          context: context,
                          routeName: "/admin",
                          builder: (_) => const AdminPanelScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 30),
            _menuCard(
              items: [
                _menuTile(Icons.person_outline, "Kişisel Bilgiler"),
                const Divider(height: 1, indent: 56),
                _menuTile(Icons.credit_card, "Ödeme Yöntemleri"),
                const Divider(height: 1, indent: 56),
                _menuTile(
                  Icons.receipt_long,
                  "Sipariş Geçmişi",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrderListScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                _menuTile(
                  Icons.location_on_outlined,
                  "Adreslerim",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddressListScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<AccessProvider>().clear();
                    auth.logout();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    "Çıkış Yap",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionCard(AuthProvider auth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _menuTile(
            Icons.menu_book_outlined,
            "Kitaplar",
            onTap: () => _openAccess(auth, "book", "Kitaplarım"),
          ),
          const Divider(height: 1, indent: 56),
          _menuTile(
            Icons.library_books,
            "Dergiler",
            onTap: () => _openAccess(auth, "magazine", "Dergi Abonelikleri"),
          ),
          const Divider(height: 1, indent: 56),
          _menuTile(
            Icons.history_edu,
            "Dergi Sayıları",
            onTap: () => _openAccess(auth, "magazine_issue", "Dergi Sayılarım"),
          ),
          const Divider(height: 1, indent: 56),
          _menuTile(
            Icons.newspaper,
            "Gazete Aboneliği",
            onTap: () => _openAccess(auth, "newspaper_subscription", "Gazete Aboneliği"),
          ),
        ],
      ),
    );
  }

  Widget _menuCard({required List<Widget> items}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuTile(
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ?? () {},
    );
  }

  Future<void> _openAccess(AuthProvider auth, String itemType, String title) async {
    if (_loadingAccess) return;
    final userId = auth.user?.id;
    if (userId == null) return;

    setState(() => _loadingAccess = true);
    List<Map<String, dynamic>> entries = [];
    try {
      entries = await _accessService.getAccess(userId: userId, itemType: itemType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erişim alınamadı: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAccess = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
        ),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loadingAccess
                    ? const Center(child: CircularProgressIndicator())
                    : entries.isEmpty
                        ? const Center(child: Text("Kayıt bulunamadı"))
                        : ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final entry = entries[i];
                              return FutureBuilder<_AccessItem>(
                                future: _resolveAccessItem(itemType, entry),
                                builder: (_, snap) {
                                  if (!snap.hasData) {
                                    return const ListTile(
                                      title: Text("Yükleniyor..."),
                                      trailing: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  final data = snap.data!;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.shade100,
                                      foregroundColor: Colors.red,
                                      child: const Icon(Icons.book),
                                    ),
                                    title: Text(data.title),
                                    subtitle: data.subtitle != null ? Text(data.subtitle!) : null,
                                    trailing: data.onTap != null
                                        ? const Icon(Icons.chevron_right)
                                        : const SizedBox.shrink(),
                                    onTap: data.onTap,
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_AccessItem> _resolveAccessItem(String type, Map<String, dynamic> entry) async {
    final itemId = entry["item_id"];
    switch (type) {
      case "book":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen kitap");
        final book = await _bookService.getBookById(itemId as int);
        final title = book?["title"]?.toString() ?? "Kitap #$itemId";
        final url = book?["book_url"]?.toString();
        return _AccessItem(
          title: title,
          subtitle: "Kitap",
          onTap: (url == null || url.isEmpty)
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        url: url,
                        title: title,
                        isPrivate: true,
                      ),
                    ),
                  );
                },
        );
      case "magazine_issue":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen sayı");
        final issue = await _magService.getIssueById(itemId as int);
        final magName = issue?["magazine"]?["name"]?.toString() ?? "Dergi";
        final issueNumber = issue?["issue_number"]?.toString() ?? "#$itemId";
        final url = issue?["file_url"]?.toString();
        return _AccessItem(
          title: "$magName - $issueNumber",
          subtitle: "Dergi Sayısı",
          onTap: (url == null || url.isEmpty)
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        url: url,
                        title: "$magName - $issueNumber",
                        isPrivate: true,
                      ),
                    ),
                  );
                },
        );
      case "magazine":
        if (itemId == null) return _AccessItem(title: "Dergi aboneliği");
        final mag = await _magService.getMagazineById(itemId as int);
        final name = mag?["name"]?.toString() ?? "Dergi #$itemId";
        return _AccessItem(
          title: name,
          subtitle: "Dergi aboneliği",
          onTap: () => _openMagazineIssues(itemId, name),
        );
      case "newspaper_subscription":
        return _AccessItem(
          title: "Gazete aboneliği",
          subtitle: "Abonelik aktif",
          onTap: null,
        );
      default:
        return _AccessItem(title: "Bilinmeyen içerik");
    }
  }

  Future<void> _openMagazineIssues(int magazineId, String name) async {
    final issues = await _magService.getIssues(magazineId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
        ),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$name Sayıları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: issues.isEmpty
                    ? const Center(child: Text("Sayı bulunamadı"))
                    : ListView.separated(
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final issue = issues[i];
                          final title = "Sayı ${issue["issue_number"]}";
                          return ListTile(
                            title: Text(title),
                            subtitle: Text("Eklenme: ${issue["added_at"] ?? ''}"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final url = issue["file_url"]?.toString();
                              if (url == null || url.isEmpty) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(
                                    url: url,
                                    title: "$name - $title",
                                    isPrivate: true,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessItem {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  _AccessItem({required this.title, this.subtitle, this.onTap});
}
