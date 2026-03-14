import 'package:flutter/material.dart';
import 'admin_users_page.dart';
import 'admin_books_page.dart';
import 'admin_magazines_page.dart';
import 'admin_newspapers_page.dart';
import 'admin_notifications_page.dart';
import 'admin_author_category_page.dart';
import 'admin_orders_page.dart';
import 'admin_stats_dashboard.dart';
import 'admin_reports_page.dart';
import 'admin_promo_codes_page.dart';
import 'admin_reviews_page.dart';
import 'admin_ekler_page.dart';
import 'admin_slider_page.dart';
import 'admin_newspaper_subscription_types_page.dart';
import 'admin_home_showcase_page.dart';
import 'admin_magazine_types_page.dart';
import 'admin_manual_newspaper_users_page.dart';
import 'admin_faq_page.dart';
import 'admin_contact_messages_page.dart';
import '../../services/loading_manager.dart';

enum AdminPage {
  dashboard,
  users,
  books,
  magazines,
  magazineTypes,
  newspapers,
  newspaperTypes,
  manualNewspaperUsers,
  faqs,
  notifications,
  contactMessages,
  promotions,
  orders,
  reviews,
  reports,
  authorCategory,
  ekler,
  sliders,
  homeShowcase,
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
                child: ListView(
                  padding: EdgeInsets.zero,
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
                    _menuItem(
                      "Dergi Tipleri",
                      Icons.bookmarks,
                      AdminPage.magazineTypes,
                    ),
                    _menuItem("Gazeteler", Icons.article, AdminPage.newspapers),
                    _menuItem(
                      "Gazete Tipleri",
                      Icons.newspaper,
                      AdminPage.newspaperTypes,
                    ),
                    _menuItem(
                      "M EGazete",
                      Icons.manage_accounts,
                      AdminPage.manualNewspaperUsers,
                    ),
                    _menuItem("SSS", Icons.quiz_outlined, AdminPage.faqs),
                    _menuItem(
                      "Bildirimler",
                      Icons.notifications,
                      AdminPage.notifications,
                    ),
                    _menuItem(
                      "İletişim Mesajları",
                      Icons.contact_mail_outlined,
                      AdminPage.contactMessages,
                    ),
                    _menuItem(
                      "Promosyon Kodları",
                      Icons.local_offer,
                      AdminPage.promotions,
                    ),
                    _menuItem(
                      "Siparişler",
                      Icons.receipt_long,
                      AdminPage.orders,
                    ),
                    _menuItem("Yorumlar", Icons.reviews, AdminPage.reviews),
                    _menuItem("Raporlar", Icons.bar_chart, AdminPage.reports),
                    _menuItem(
                      "Yazar & Kategori",
                      Icons.list,
                      AdminPage.authorCategory,
                    ),
                    _menuItem("Ekler", Icons.file_present, AdminPage.ekler),
                    _menuItem("Sliderlar", Icons.slideshow, AdminPage.sliders),
                    _menuItem(
                      "Anasayfa Gösterimi",
                      Icons.home,
                      AdminPage.homeShowcase,
                    ),
                    _menuItem("Ayarlar", Icons.settings, AdminPage.settings),
                    const SizedBox(height: 16),
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
                      color: Colors.black.withValues(alpha: 0.4),
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
      case AdminPage.magazineTypes:
        return const AdminMagazineTypesPage();
      case AdminPage.newspapers:
        return const AdminNewspapersPage();
      case AdminPage.newspaperTypes:
        return const AdminNewspaperSubscriptionTypesPage();
      case AdminPage.manualNewspaperUsers:
        return const AdminManualNewspaperUsersPage();
      case AdminPage.faqs:
        return const AdminFaqPage();
      case AdminPage.notifications:
        return const AdminNotificationsPage();
      case AdminPage.contactMessages:
        return const AdminContactMessagesPage();
      case AdminPage.promotions:
        return const AdminPromoCodesPage();
      case AdminPage.orders:
        return const AdminOrdersPage();
      case AdminPage.reviews:
        return const AdminReviewsPage();
      case AdminPage.reports:
        return const AdminReportsPage();
      case AdminPage.authorCategory:
        return const AdminAuthorCategoryPage();
      case AdminPage.ekler:
        return const AdminEklerPage();
      case AdminPage.sliders:
        return const AdminSliderPage();
      case AdminPage.homeShowcase:
        return const AdminHomeShowcasePage();
      case AdminPage.settings:
        return const Center(child: Text("Ayarlar Sayfası"));
      default:
        return const AdminStatsDashboard();
    }
  }
}
