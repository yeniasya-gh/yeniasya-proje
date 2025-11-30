import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/access_provider.dart';
import '/screen/footer//yeni_asya_footer.dart';
import '/services/auth/auth_provider.dart';
import '/screen/login/login_screen.dart';
import '/screen/profile/profile_screen.dart';
import '/utils/route_guard.dart';
import '/screen/cart/cart_screen.dart';
import '../services/admin/admin_magazine_service.dart';
import '../services/admin/admin_book_service.dart';
import '../services/admin/admin_newspaper_service.dart';
import '../services/cart/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/upload_service.dart';
import '../services/access_provider.dart';
import '../screen/profile/pdf_viewer_screen.dart';
import 'search/search_screen.dart';
import 'product/product_detail_screen.dart';
import '../utils/safe_image.dart';

enum HomeSection { home, magazines, books, newspapers }

class HomeResponsiveScreen extends StatefulWidget {
  const HomeResponsiveScreen({super.key});

  @override
  State<HomeResponsiveScreen> createState() => _HomeResponsiveScreenState();
}

class _HomeResponsiveScreenState extends State<HomeResponsiveScreen> {
  HomeSection _section = HomeSection.home;

  final AdminMagazineService _magService = AdminMagazineService();
  final AdminBookService _bookService = AdminBookService();
  final AdminNewspaperService _newsService = AdminNewspaperService();

  List<Map<String, dynamic>> magazines = [];
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> newspapers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAccessIfNeeded();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final mag = await _magService.getMagazines();
      final book = await _bookService.getAllBooks();
      final news = await _newsService.getAll();
      setState(() {
        magazines = mag;
        books = book;
        newspapers = news;
      });
    } catch (e) {
      debugPrint("Home load error: $e");
    }
    setState(() => loading = false);
  }

  Future<void> _loadAccessIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;
      if (userId == null) return;
      await context.read<AccessProvider>().load(userId);
    });
  }

  double _parsePrice(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? "") ?? fallback;
  }

  void _openProductDetail(ProductDetail detail) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(detail: detail)),
    );
  }

  void _openSearch({String initialQuery = ""}) {
    Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          books: books,
          magazines: magazines,
          newspapers: newspapers,
          initialQuery: initialQuery,
        ),
        fullscreenDialog: true,
      ),
    ).then((result) {
      if (result == null) return;
      final item = result["item"] as Map<String, dynamic>?;
      final type = result["type"] as String?;
      if (item == null || type == null) return;

      if (type == "book") {
        _openProductDetail(_mapBookDetail(item));
      } else if (type == "magazine") {
        _openProductDetail(_mapMagazineDetail(item));
      } else {
        _openProductDetail(_mapNewspaperDetail(item));
      }
    });
  }

  ProductDetail _mapMagazineDetail(Map<String, dynamic> mag) {
    final hasAccess = context.read<AccessProvider>().hasAccess("magazine", itemId: mag["id"] as int?);
    final actionLabel = hasAccess ? "Dergiyi Gör" : "Abone Ol";
    final price = _parsePrice(mag["campaign_price"] ?? mag["sale_price"]);
    return ProductDetail(
      id: "mag-${mag["id"]}",
      title: mag["name"] ?? "",
      subtitle: mag["category"] ?? "",
      description: mag["description"] ?? mag["category"] ?? "",
      imageUrl: mag["cover_image_url"] ?? "",
      price: price,
      type: CartItemType.magazine,
      metadata: {
        "productId": mag["id"],
        "disableAdd": hasAccess,
        "fileUrl": null,
      },
      actionLabel: actionLabel,
    );
  }

  ProductDetail _mapBookDetail(Map<String, dynamic> book) {
    final hasAccess = context.read<AccessProvider>().hasAccess("book", itemId: book["id"] as int?);
    final actionLabel = hasAccess ? "Kitabı Gör" : "Sepete Ekle";
    final price = _parsePrice(book["price"]);
    return ProductDetail(
      id: "book-${book["id"]}",
      title: book["title"] ?? "",
      subtitle: book["author_rel"]?["name"] ?? "",
      description: book["description"] ?? book["min_description"] ?? "",
      imageUrl: book["cover_url"] ?? "",
      price: price,
      type: CartItemType.book,
      metadata: {
        "productId": book["id"],
        "fileUrl": book["book_url"],
        "disableAdd": hasAccess,
      },
      actionLabel: actionLabel,
    );
  }

  ProductDetail _mapNewspaperDetail(Map<String, dynamic> news) {
    final dateStr = news["publish_date"]?.toString() ?? "";
    final hasSub = context.read<AccessProvider>().hasAccess("newspaper_subscription");
    final title = "Gündem Gazetesi";
    final fileUrl = news["file_url"]?.toString();
    return ProductDetail(
      id: "news-${news["id"] ?? "subscription"}",
      title: title,
      subtitle: dateStr,
      description: dateStr.isNotEmpty ? "Yayın tarihi: $dateStr" : "Günlük gazete aboneliği.",
      imageUrl: news["image_url"] ?? "",
      price: 1.0,
      type: CartItemType.newspaperSubscription,
      metadata: {
        "productId": "gazete-abonelik",
        "disableAdd": hasSub,
        "fileUrl": fileUrl,
      },
      actionLabel: hasSub ? "Gazeteyi Gör" : "Abone Ol",
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: isWeb ? 1 : 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : (isTablet ? 32 : 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        "assets/images/logo.png",
                        height: isWeb ? 40 : 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 32),
                      if (isWeb)
                        Row(
                          children: [
                            _menuItem("Anasayfa", HomeSection.home),
                            _menuItem("Dergiler", HomeSection.magazines),
                            _menuItem("Kitaplar", HomeSection.books),
                            _menuItem("Gazeteler", HomeSection.newspapers),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isWeb)
                        SizedBox(
                          width: 240,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Ara...",
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (q) => _openSearch(initialQuery: q),
                            onTap: () => _openSearch(),
                            readOnly: true,
                          ),
                        ),
                      if (isWeb) const SizedBox(width: 12),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _cartCount(cart) > 0 ? Colors.red : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _cartCount(cart).toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isWeb && !auth.isLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Giriş Yap"),
                          ),
                        ),
                      if (isWeb && auth.isLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                RouteGuard.guard(
                                  context: context,
                                  routeName: "/profile",
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Profilim"),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isWeb)
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFEEEEEE),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1600),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWeb ? 64 : (isTablet ? 32 : 16),
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 500),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_section == HomeSection.home) ...[
                                _buildPremiumCard(isWeb),
                                const SizedBox(height: 20),
                              ],
                              _buildBodyContent(isWeb, isTablet, cart),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isWeb) const YeniAsyaFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWeb
          ? null
          : BottomNavigationBar(
              selectedItemColor: Colors.red,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              currentIndex: 0,
              onTap: (index) {
                if (index == 1) {
                  _openSearch();
                }
                if (index == 3) {
                  if (auth.isLoggedIn) {
                    Navigator.push(
                      context,
                      RouteGuard.guard(
                        context: context,
                        routeName: "/profile",
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ana Sayfa"),
                BottomNavigationBarItem(icon: Icon(Icons.search), label: "Ara"),
                BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: "Kaydedilenler"),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profil"),
              ],
            ),
    );
  }

  Widget _buildBodyContent(bool isWeb, bool isTablet, CartProvider cart) {
    switch (_section) {
      case HomeSection.magazines:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("Dergiler"),
            const SizedBox(height: 16),
            _magazineListGrid(context, isWeb),
          ],
        );
      case HomeSection.books:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("Kitaplar"),
            const SizedBox(height: 16),
            _bookListGrid(context, isWeb, isTablet),
            const SizedBox(height: 24),
          ],
        );
      case HomeSection.newspapers:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("Gazeteler"),
            const SizedBox(height: 16),
            _newspaperListGrid(context, isWeb),
          ],
        );
      case HomeSection.home:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _magazineShowcase(context, isWeb, cart),
            const SizedBox(height: 32),
            _booksShowcase(context, isWeb, cart),
            const SizedBox(height: 32),
            _newspaperShowcase(context, isWeb, cart),
            const SizedBox(height: 32),
          ],
        );
    }
  }

  Widget _buildPremiumCard(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: isWeb ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          Expanded(
            flex: isWeb ? 2 : 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Premium Abonelik",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("Tüm içeriklere sınırsız erişim", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Şimdi Başla"),
                ),
              ],
            ),
          ),
          if (isWeb)
            const Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.emoji_events_rounded, color: Colors.white70, size: 60),
              ),
            ),
        ],
      ),
    );
  }

Widget _magazineShowcase(BuildContext context, bool isWeb, CartProvider cart) {
  final crossAxisCount = isWeb ? 4 : (isTabletLayout(context) ? 3 : 1);
  if (magazines.isEmpty) return const SizedBox.shrink();
  final access = context.watch<AccessProvider>();

  return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Öne Çıkan Dergiler",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.magazines);
            } else {
              _openFullList(context, "Dergiler",
                  (ctx) => _magazineListGrid(ctx, false));
            }
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / crossAxisCount;
            final cardHeight =
                isWeb ? 280.0 : (itemWidth * 0.9).clamp(0, 320).toDouble();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: magazines.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: cardHeight,
              ),
              itemBuilder: (_, i) {
                final hideAction = access.hasAccess("magazine", itemId: magazines[i]["id"] as int?);
                return _magazineCard({
                  "image": magazines[i]["cover_image_url"],
                  "title": magazines[i]["name"],
                  "desc": magazines[i]["description"] ?? magazines[i]["category"],
                  "price": magazines[i]["sale_price"] != null
                      ? "₺${double.tryParse(magazines[i]["sale_price"].toString())?.toStringAsFixed(2) ?? ""}"
                      : "-",
                }, hideAction: hideAction, onAdd: hideAction
                    ? null
                    : () {
                        _addToCart(
                          context,
                          cart,
                          CartItem(
                            id: "mag-${magazines[i]["id"]}",
                            title: magazines[i]["name"] ?? "",
                            subtitle: magazines[i]["category"] ?? "",
                            imageUrl: magazines[i]["cover_image_url"] ?? "",
                            price: double.tryParse(magazines[i]["sale_price"]?.toString() ?? "0") ?? 0,
                            quantity: 1,
                            type: CartItemType.magazine,
                            metadata: {"productId": magazines[i]["id"]},
                          ),
                        );
                      }, onTap: () {
                  _openProductDetail(_mapMagazineDetail(magazines[i]));
                });
              },
            );
          },
        ),
      ],
    );
}

Widget _booksShowcase(BuildContext context, bool isWeb, CartProvider cart) {
    final access = context.watch<AccessProvider>();
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Popüler Kitaplar",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.books);
            } else {
              _openFullList(context, "Kitaplar",
                  (ctx) => _bookListGrid(ctx, false, false));
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isWeb ? 270 : 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _bookCard({
              "image": books[i]["cover_url"],
              "title": books[i]["title"],
              "author": books[i]["author_rel"]?["name"] ?? "-",
              "price": books[i]["price"] != null
                  ? "₺${double.tryParse(books[i]["price"].toString())?.toStringAsFixed(2) ?? ""}"
                  : "-",
            }, isWeb,
                hideAction: access.hasAccess("book", itemId: books[i]["id"] as int?),
                onAdd: () {
                  _addToCart(
                    context,
                    cart,
                    CartItem(
                      id: "book-${books[i]["id"]}",
                      title: books[i]["title"] ?? "",
                      subtitle: books[i]["author_rel"]?["name"] ?? "",
                      imageUrl: books[i]["cover_url"] ?? "",
                      price: double.tryParse(books[i]["price"]?.toString() ?? "0") ?? 0,
                      quantity: 1,
                      type: CartItemType.book,
                      metadata: {"productId": books[i]["id"]},
                    ),
                  );
                }, onTap: () {
              _openProductDetail(_mapBookDetail(books[i]));
            }),
          ),
        ),
      ],
    );
  }

  Widget _newspaperShowcase(BuildContext context, bool isWeb, CartProvider cart) {
    final access = context.watch<AccessProvider>();
    const fallbackImage = "assets/images/gazete.jpg";
    final today = DateTime.now();
    final items = newspapers.take(10).map((n) {
      final dateStr = n["publish_date"]?.toString() ?? "";
      final d = DateTime.tryParse(dateStr);
      final label = d != null ? _formatDateTr(d) : dateStr;
      return {
        "image": n["image_url"] ?? fallbackImage,
        "date": label.isNotEmpty ? label : _formatDateTr(today),
        "title": "Gündem Gazetesi",
        "raw": n,
      };
    }).toList();

    final subscriptionImage =
        items.isNotEmpty ? (items.first["image"] as String? ?? fallbackImage) : fallbackImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Günlük Gazeteler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (!access.hasAccess("newspaper_subscription"))
              ElevatedButton(
                onPressed: () {
                  _addToCart(
                    context,
                    cart,
                    CartItem(
                      id: "news-subscription",
                      title: "Gazete Aboneliği",
                      subtitle: "Aylık abonelik",
                      imageUrl: subscriptionImage,
                      price: 1.0,
                      quantity: 1,
                      type: CartItemType.newspaperSubscription,
                      metadata: {"productId": "gazete-abonelik"},
                    ),
                  );
                  if (isWeb) {
                    setState(() => _section = HomeSection.newspapers);
                  } else {
                  _openFullList(context, "Gazeteler",
                      (ctx) => _newspaperListGrid(ctx, false));
                }
              },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Abone Ol"),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isNotEmpty)
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _newspaperPreviewCard(
                items[i],
                onTap: () => _openProductDetail(_mapNewspaperDetail(items[i]["raw"] as Map<String, dynamic>)),
              ),
            ),
          ),
      ],
    );
  }

Widget _magazineListGrid(BuildContext context, bool isWeb) {
  final cart = Provider.of<CartProvider>(context, listen: false);
  final access = Provider.of<AccessProvider>(context, listen: false);
  final crossAxisCount = isWeb ? 4 : (isTabletLayout(context) ? 2 : 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / crossAxisCount;
        final cardHeight =
            isWeb ? 280.0 : (itemWidth * 0.9).clamp(0, 300).toDouble();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: cardHeight,
          ),
          itemCount: magazines.length,
          itemBuilder: (_, i) {
            final hideAction = access.hasAccess("magazine", itemId: magazines[i]["id"] as int?);
            return _magazineCard({
              "image": magazines[i]["cover_image_url"],
              "title": magazines[i]["name"],
              "desc": magazines[i]["description"] ?? magazines[i]["category"],
              "price": magazines[i]["sale_price"] != null
                  ? "₺${double.tryParse(magazines[i]["sale_price"].toString())?.toStringAsFixed(2) ?? ""}"
                  : "-",
            },
                hideAction: hideAction,
                onAdd: hideAction
                    ? null
                    : () {
                        _addToCart(
                          context,
                          cart,
                          CartItem(
                            id: "mag-${magazines[i]["id"]}",
                            title: magazines[i]["name"] ?? "",
                            subtitle: magazines[i]["category"] ?? "",
                            imageUrl: magazines[i]["cover_image_url"] ?? "",
                            price: double.tryParse(magazines[i]["sale_price"]?.toString() ?? "0") ?? 0,
                            quantity: 1,
                            type: CartItemType.magazine,
                            metadata: {"productId": magazines[i]["id"]},
                          ),
                        );
                      }, onTap: () {
              _openProductDetail(_mapMagazineDetail(magazines[i]));
            });
          },
        );
      },
    );
  }

Widget _bookListGrid(BuildContext context, bool isWeb, bool isTablet) {
  final cart = Provider.of<CartProvider>(context, listen: false);
  final access = context.watch<AccessProvider>();
  final crossAxisCount = isWeb ? 4 : (isTablet ? 3 : 2);
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      mainAxisExtent: isWeb ? 270 : 260,
    ),
      itemCount: books.length,
      itemBuilder: (_, i) => _bookCard({
        "image": books[i]["cover_url"],
        "title": books[i]["title"],
        "author": books[i]["author_rel"]?["name"] ?? "-",
        "price": books[i]["price"] != null
            ? "₺${double.tryParse(books[i]["price"].toString())?.toStringAsFixed(2) ?? ""}"
            : "-",
      }, isWeb,
          hideAction: access.hasAccess("book", itemId: books[i]["id"] as int?),
          onAdd: () {
        _addToCart(
          context,
          cart,
          CartItem(
            id: "book-${books[i]["id"]}",
            title: books[i]["title"] ?? "",
            subtitle: books[i]["author_rel"]?["name"] ?? "",
            imageUrl: books[i]["cover_url"] ?? "",
            price: double.tryParse(books[i]["price"]?.toString() ?? "0") ?? 0,
            quantity: 1,
            type: CartItemType.book,
            metadata: {"productId": books[i]["id"]},
          ),
        );
      }, onTap: () {
        _openProductDetail(_mapBookDetail(books[i]));
      }),
    );
  }

  Widget _newspaperListGrid(BuildContext context, bool isWeb) {
    final crossAxisCount = isWeb ? 3 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final childAspectRatio = isWeb ? 2.4 : 1.4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: newspapers.length,
          itemBuilder: (_, i) {
            final hasSub = context.watch<AccessProvider>().hasAccess("newspaper_subscription");
            return _newspaperCard({
              "icon": newspapers[i]["image_url"],
              "title": "Gündem Gazetesi",
              "desc": newspapers[i]["publish_date"] ?? "",
              "price": "",
            }, onTap: () => _openProductDetail(_mapNewspaperDetail(newspapers[i])),
                hideAction: hasSub);
          },
        );
      },
    );
  }

  Widget _menuItem(String title, HomeSection target) {
    final active = _section == target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _section = target),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: active ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

bool isTabletLayout(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width > 600 && width <= 1024;
}

Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      TextButton(
        onPressed: onViewAll,
        child: const Text("Tümünü Gör", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
      ),
    ],
  );
}

Widget _sectionHeadingText(String title) {
  return Text(
    title,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
  );
}

Widget _magazineCard(Map<String, dynamic> item, {VoidCallback? onAdd, VoidCallback? onTap, bool hideAction = false}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: _imageWidget(item["image"], height: 170),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item["title"] ?? "", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  item["desc"] ?? "",
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item["price"] ?? "",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (!hideAction && onAdd != null)
                      ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Abone Ol"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _bookCard(Map<String, dynamic> item, bool isWeb,
    {VoidCallback? onAdd, VoidCallback? onTap, bool hideAction = false}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: isWeb ? 160 : 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: _imageWidget(item["image"], height: 150),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item["author"] ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item["price"] ?? "",
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                      ),
                      if (!hideAction)
                        Container(
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            onPressed: onAdd,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _newspaperCard(Map<String, dynamic> item, {VoidCallback? onTap, bool hideAction = false}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _imageWidget(item["icon"], width: 70, height: 70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["title"] ?? "",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item["desc"] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 13.5),
                ),
                 const SizedBox(height: 10),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       item["price"] ?? "",
                       style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 15.5),
                     ),
                    if (!hideAction)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: const Text(
                          "Abone Ol",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                   ],
                 ),
               ],
             ),
           ),
        ],
      ),
    ),
  );
}

Widget _newspaperPreviewCard(Map<String, dynamic> item, {VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 170,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: _imageWidget(item["image"], height: 170),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["title"] ?? "",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item["date"] ?? "",
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _imageWidget(String? url, {double? height, double? width}) {
  final double h = height ?? 150;
  final double w = width ?? double.infinity;

  return safeImage(
    UploadService.normalizeUrl(url ?? ""),
    height: h,
    width: w,
    fallbackIcon: Icons.broken_image,
  );
}

String _formatDateTr(DateTime date) {
  const months = [
    "Ocak",
    "Şubat",
    "Mart",
    "Nisan",
    "Mayıs",
    "Haziran",
    "Temmuz",
    "Ağustos",
    "Eylül",
    "Ekim",
    "Kasım",
    "Aralık"
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  return "$day $month $year";
}

int _cartCount(CartProvider cart) {
  return cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
}

void _addToCart(BuildContext context, CartProvider cart, CartItem item) {
  cart.addOrIncrement(item);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Sepete eklendi")),
  );
}

void _openFullList(
  BuildContext context,
  String title,
  Widget Function(BuildContext) builder,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text(title),
          elevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
  );
}
