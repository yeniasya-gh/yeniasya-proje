import 'package:flutter/material.dart';
import 'admin_users_page.dart';
import 'admin_books_page.dart';
import 'admin_magazines_page.dart';
import 'admin_newspapers_page.dart';
import 'admin_author_category_page.dart';
import 'admin_orders_page.dart';
import 'admin_stats_dashboard.dart';
import 'admin_reports_page.dart';
import '../../services/loading_manager.dart';

enum AdminPage {
  dashboard,
  users,
  books,
  magazines,
  newspapers,
  orders,
  reports,
  authorCategory,
  settings,
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  AdminPage selectedPage = AdminPage.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // 🔥 SOL MENÜ
              Container(
                width: 240,
                color: Colors.grey.shade900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                        IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Yönetim Paneli",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _menuItem("Anasayfa", Icons.dashboard, AdminPage.dashboard),
                    _menuItem("Kullanıcılar", Icons.people, AdminPage.users),
                    _menuItem("Kitaplar", Icons.menu_book, AdminPage.books),
                    _menuItem("Dergiler", Icons.menu_book, AdminPage.magazines),
                    _menuItem("Gazeteler", Icons.article, AdminPage.newspapers),
                    _menuItem("Siparişler", Icons.receipt_long, AdminPage.orders),
                    _menuItem("Raporlar", Icons.bar_chart, AdminPage.reports),
                    _menuItem("Yazar & Kategori", Icons.list, AdminPage.authorCategory),
                    _menuItem("Ayarlar", Icons.settings, AdminPage.settings),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xFFF4F5F7),
                  child: _buildPage(),
                ),
              ),
            ],
          ),
          // GLOBAL LOADING OVERLAY
          AnimatedBuilder(
            animation: LoadingManager.instance,
            builder: (_, __) {
              return LoadingManager.instance.loading
                  ? Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : const SizedBox();
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(String title, IconData icon, AdminPage page) {
    final bool active = selectedPage == page;

    return InkWell(
      onTap: () {
        setState(() => selectedPage = page);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        color: active ? Colors.grey.shade800 : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
  switch (selectedPage) {
    case AdminPage.users:
      return const AdminUsersPage();
    case AdminPage.books:
      return const AdminBooksPage();
    case AdminPage.magazines:
      return const AdminMagazinesPage();
    case AdminPage.newspapers:
      return const AdminNewspapersPage();
    case AdminPage.orders:
      return const AdminOrdersPage();
    case AdminPage.reports:
      return const AdminReportsPage();
    case AdminPage.authorCategory:
      return const AdminAuthorCategoryPage();
    case AdminPage.settings:
      return const Center(child: Text("Ayarlar Sayfası"));
    default:
      return const AdminStatsDashboard();
  }
}
}
