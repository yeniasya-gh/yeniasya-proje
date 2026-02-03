import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import '../models/app_flags.dart';
import '../services/access_provider.dart';
import '/screen/footer/yeni_asya_footer.dart';
import '/services/auth/auth_provider.dart';
import '/screen/login/login_screen.dart';
import '/screen/profile/profile_screen.dart';
import '/utils/route_guard.dart';
import '/screen/cart/cart_screen.dart';
import '/screen/order/order_list_screen.dart';
import '/screen/order/order_detail_screen.dart';
import '../services/admin/admin_magazine_service.dart';
import '../services/admin/admin_book_service.dart';
import '../services/admin/admin_newspaper_service.dart';
import '../services/admin/admin_slider_service.dart';
import '../services/ek_service.dart';
import '../services/cart/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/order_service.dart';
import '../services/user_content_access_service.dart';
import '../services/newspaper_subscription_type_service.dart';
import '../services/upload_service.dart';
import '../services/access_provider.dart';
import '../services/home_showcase_service.dart';
import '../services/app_flag_service.dart';
import '../screen/profile/pdf_viewer_screen.dart';
import '../utils/cart_feedback.dart';
import '../utils/price_utils.dart';
import '../utils/pdf_open_helper.dart';
import 'search/search_screen.dart';
import 'product/product_detail_screen.dart';
import '../utils/safe_image.dart';
import '../utils/ek_normalizer.dart';
import 'attachment/ek_detail_screen.dart';
import 'slider/slider_detail_screen.dart';
import 'slider/slider_webview_screen.dart';
import 'privacy/privacy_screen.dart';

enum HomeSection { home, magazines, books, newspapers, attachments }

class HomeResponsiveScreen extends StatefulWidget {
  final Uri? initialUri;

  const HomeResponsiveScreen({super.key, this.initialUri});

  @override
  State<HomeResponsiveScreen> createState() => _HomeResponsiveScreenState();
}

class _HomeResponsiveScreenState extends State<HomeResponsiveScreen> {
  HomeSection _section = HomeSection.home;

  final AdminMagazineService _magService = AdminMagazineService();
  final AdminBookService _bookService = AdminBookService();
  final AdminNewspaperService _newsService = AdminNewspaperService();
  final AdminSliderService _sliderService = AdminSliderService();
  final EkService _ekService = EkService();
  final OrderService _orderService = OrderService();
  final UserContentAccessService _accessService = UserContentAccessService();
  final NewspaperSubscriptionTypeService _newsTypeService =
      NewspaperSubscriptionTypeService();
  final HomeShowcaseService _homeShowcaseService = HomeShowcaseService();
  final AppFlagService _appFlagService = AppFlagService();

  final PageController _sliderController = PageController();
  Timer? _sliderTimer;
  int _sliderIndex = 0;

  List<Map<String, dynamic>> sliders = [];
  List<Map<String, dynamic>> magazines = [];
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> newspapers = [];
  List<Map<String, dynamic>> attachments = [];
  List<Map<String, dynamic>> homeBookEntries = [];
  List<Map<String, dynamic>> homeMagazineEntries = [];
  bool loading = true;
  int _mobileNavIndex = 0;
  bool libraryLoading = false;
  List<Map<String, dynamic>> libraryOrders = [];
  bool libraryAccessLoading = false;
  List<Map<String, dynamic>> libraryAccess = [];
  bool _loadingAccessSheet = false;
  bool _deepLinkHandled = false;
  bool _flagsLoaded = false;
  AuthProvider? _authListener;
  DateTime? _newsSelectedDate;
  AppFlags _appFlags = AppFlags.defaults;

  bool get _hideMagazines => _appFlags.hideMagazines;
  bool get _hideNewspapers => _appFlags.hideNewspapers;
  bool get _freeMagNews => _hideMagazines && _hideNewspapers;
  bool get _effectiveHideMagazines => _hideMagazines && !_freeMagNews;
  bool get _effectiveHideNewspapers => _hideNewspapers && !_freeMagNews;
  bool get _storeFlagEnabled => _hideMagazines || _hideNewspapers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authListener = context.read<AuthProvider>();
      _authListener?.addListener(_onAuthChange);
    });
    _loadAppFlags();
    _loadData();
    _loadAccessIfNeeded();
    _loadLibraryOrders();
    _loadLibraryAccess();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => loading = true);
    }
    try {
      final results = await Future.wait([
        _magService.getMagazines(),
        _bookService.getAllBooks(),
        _newsService.getAll(),
        _ekService.getEkler(),
        _sliderService.getAll(onlyActive: true),
        _homeShowcaseService.getByType("book", onlyActive: true),
        _homeShowcaseService.getByType("magazine", onlyActive: true),
      ]);

      final mag = results[0] as List<Map<String, dynamic>>;
      final book = results[1] as List<Map<String, dynamic>>;
      final news = results[2] as List<Map<String, dynamic>>;
      final eks = results[3] as List<Map<String, dynamic>>;
      final sliderItems = results[4] as List<Map<String, dynamic>>;
      final homeBooks = results[5] as List<Map<String, dynamic>>;
      final homeMags = results[6] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        sliders = sliderItems;
        _sliderIndex = 0;
        magazines = mag;
        books = book;
        newspapers = news;
        attachments = eks;
        homeBookEntries = homeBooks;
        homeMagazineEntries = homeMags;
      });
      _startSliderAuto();
      await _handleInitialDeepLink();
    } catch (e) {
      debugPrint("Home load error: $e");
    }
    if (showLoading && mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadAppFlags() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber;
      final version = build.isNotEmpty
          ? "${info.version}+$build"
          : info.version;
      final flags = await _appFlagService.fetchFlags(version: version);
      if (!mounted) return;
      setState(() {
        _appFlags = flags;
        _flagsLoaded = true;
        if (_effectiveHideMagazines && _section == HomeSection.magazines) {
          _section = HomeSection.home;
        }
        if (_effectiveHideNewspapers && _section == HomeSection.newspapers) {
          _section = HomeSection.home;
        }
      });
    } catch (e) {
      debugPrint("App flag load error: $e");
      if (!mounted) return;
      setState(() {
        _flagsLoaded = true;
      });
    }
  }

  Future<void> _refreshHome() async {
    await _loadData(showLoading: false);
    await _loadLibraryOrders();
    await _loadLibraryAccess();
    await _loadAppFlags();
    _loadAccessIfNeeded();
  }

  void _startSliderAuto() {
    _sliderTimer?.cancel();
    if (sliders.isEmpty) {
      _sliderIndex = 0;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sliderController.hasClients) {
        _sliderController.jumpToPage(_sliderIndex);
      }
    });
    if (sliders.length <= 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sliderController.hasClients) return;
      _sliderTimer?.cancel();
      _sliderTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_sliderController.hasClients) return;
        final nextIndex = (_sliderIndex + 1) % sliders.length;
        _sliderController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  Future<void> _loadLibraryOrders() async {
    setState(() => libraryLoading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) {
        if (mounted) {
          setState(() => libraryOrders = []);
        }
        return;
      }
      final orders = await _orderService.getOrdersWithItems(userId);
      if (mounted) {
        setState(() => libraryOrders = orders);
      }
    } catch (e) {
      debugPrint("Library load error: $e");
    } finally {
      if (mounted) {
        setState(() => libraryLoading = false);
      }
    }
  }

  void _onAuthChange() {
    final auth = _authListener;
    if (auth == null) return;
    _loadLibraryOrders();
    _loadLibraryAccess();
    if (auth.isLoggedIn) {
      _loadData();
      _loadAccessIfNeeded();
    } else {
      _resetAfterLogout();
    }
  }

  void _resetAfterLogout() {
    if (!mounted) return;
    setState(() {
      loading = true;
      _flagsLoaded = false;
      _section = HomeSection.home;
      _mobileNavIndex = 0;
      libraryOrders = [];
      libraryAccess = [];
    });
    _loadAppFlags();
    _loadData();
  }

  Future<void> _loadLibraryAccess() async {
    setState(() => libraryAccessLoading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        final entries = await _accessService.getAll(userId: userId);
        if (mounted) setState(() => libraryAccess = entries);
      } else {
        if (mounted) setState(() => libraryAccess = []);
      }
    } catch (e) {
      debugPrint("Library access load error: $e");
    }
    if (mounted) setState(() => libraryAccessLoading = false);
  }

  Future<void> _handleInitialDeepLink() async {
    if (_deepLinkHandled || widget.initialUri == null) return;
    final uri = widget.initialUri!;
    final type = uri.queryParameters["type"];
    final id = int.tryParse(uri.queryParameters["id"] ?? "");
    if ((_effectiveHideMagazines && type == "magazine") ||
        (_effectiveHideNewspapers &&
            (type == "newspaper" || type == "newspaper_subscription"))) {
      return;
    }
    if (type == null || id == null) return;

    ProductDetail? detail;
    switch (type) {
      case "book":
        final data = books.firstWhere((b) => b["id"] == id, orElse: () => {});
        if (data.isNotEmpty) detail = _mapBookDetail(data);
        break;
      case "magazine":
        final data = magazines.firstWhere(
          (m) => m["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) detail = _mapMagazineDetail(data);
        break;
      case "magazine_issue":
        break;
      case "newspaper_subscription":
        final data = newspapers.firstWhere(
          (n) => n["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) detail = _mapNewspaperDetail(data);
        break;
      case "ek":
        final data = attachments.firstWhere(
          (n) => n["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _deepLinkHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openEkDetail(data);
          });
        }
        return;
    }

    if (detail != null) {
      _deepLinkHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openProductDetail(detail!);
      });
    }
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

  @override
  void dispose() {
    _authListener?.removeListener(_onAuthChange);
    _sliderTimer?.cancel();
    _sliderController.dispose();
    super.dispose();
  }

  double _parsePrice(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? "") ?? fallback;
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Map<String, dynamic>> _filteredNewspapers() {
    final hasFilter = _newsSelectedDate != null;
    if (!hasFilter) return newspapers;

    final cutoff = DateTime(2026, 1, 1);
    final targets = <DateTime>[];
    if (_newsSelectedDate != null) {
      targets.add(_normalizeDate(_newsSelectedDate!));
    }

    final results = <Map<String, dynamic>>[];
    for (final date in targets) {
      if (!date.isBefore(cutoff)) {
        final match = newspapers.firstWhere((n) {
          final raw = n["publish_date"]?.toString();
          if (raw == null) return false;
          final parsed = DateTime.tryParse(raw);
          if (parsed == null) return false;
          return _normalizeDate(parsed) == date;
        }, orElse: () => {});
        if (match.isNotEmpty) results.add(match);
      }
    }
    return results;
  }

  void _openProductDetail(ProductDetail detail) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(detail: detail)),
    );
  }

  void _openEkDetail(Map<String, dynamic> ek) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EkDetailScreen(ek: normalizeEk(ek))),
    );
  }

  void _openPdfDirect(
    String url, {
    required String title,
    required bool isPublic,
  }) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("PDF bulunamadı")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: UploadService.normalizeUrl(url),
          title: title,
          // Ücretsiz ekler de private modda açılacak
          isPrivate: true,
        ),
      ),
    );
  }

  Uri? _parseSliderUri(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return Uri.tryParse(trimmed);
    }
    if (trimmed.startsWith("?")) {
      return Uri.tryParse("https://local/$trimmed");
    }
    if (trimmed.contains("type=") &&
        trimmed.contains("id=") &&
        !trimmed.contains("://")) {
      return Uri.tryParse("https://local/?$trimmed");
    }
    return Uri.tryParse(trimmed);
  }

  Future<void> _handleSliderLink(Map<String, dynamic> slide) async {
    final link = (slide["link_url"] ?? "").toString().trim();
    if (link.isEmpty) return;
    final uri = _parseSliderUri(link);
    if (uri != null) {
      final type = uri.queryParameters["type"];
      final id = int.tryParse(uri.queryParameters["id"] ?? "");
      if (type != null && id != null) {
        final opened = _openSliderTarget(type, id);
        if (opened) return;
      }
    }
    if (uri == null || !(uri.scheme == "http" || uri.scheme == "https")) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Link açılamadı.")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SliderWebViewScreen(
          url: uri.toString(),
          title: (slide["title"] ?? "Duyuru").toString(),
        ),
      ),
    );
  }

  void _handleSliderTap(Map<String, dynamic> slide) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SliderDetailScreen(
          slide: slide,
          onOpenLink: () => _handleSliderLink(slide),
        ),
      ),
    );
  }

  bool _openSliderTarget(String type, int id) {
    if ((_effectiveHideMagazines && type == "magazine") ||
        (_effectiveHideNewspapers &&
            (type == "newspaper_subscription" || type == "newspaper"))) {
      return false;
    }
    switch (type) {
      case "book":
        final data = books.firstWhere((b) => b["id"] == id, orElse: () => {});
        if (data.isNotEmpty) {
          _openProductDetail(_mapBookDetail(data));
          return true;
        }
        return false;
      case "magazine":
        final data = magazines.firstWhere(
          (m) => m["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _openProductDetail(_mapMagazineDetail(data));
          return true;
        }
        return false;
      case "newspaper_subscription":
      case "newspaper":
        final data = newspapers.firstWhere(
          (n) => n["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _openProductDetail(_mapNewspaperDetail(data));
          return true;
        }
        return false;
      case "ek":
        final data = attachments.firstWhere(
          (e) => e["id"] == id,
          orElse: () => {},
        );
        if (data.isNotEmpty) {
          _openEkDetail(data);
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  void _openSearch({String initialQuery = ""}) {
    Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          books: books,
          magazines: _effectiveHideMagazines ? [] : magazines,
          newspapers: _effectiveHideNewspapers ? [] : newspapers,
          attachments: attachments,
          initialQuery: initialQuery,
          hideMagazines: _effectiveHideMagazines,
          hideNewspapers: _effectiveHideNewspapers,
          freeMagNews: _freeMagNews,
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
      } else if (type == "ek") {
        _openEkDetail(item);
      } else {
        _openProductDetail(_mapNewspaperDetail(item));
      }
    });
  }

  Future<void> _selectNewspaperSubscriptionType(
    BuildContext context,
    CartProvider cart, {
    required String imageUrl,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      showLoginRequirementDialog(context);
      return;
    }
    try {
      final list = await _newsTypeService.getActiveTypes();
      if (!mounted) return;
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gazete abonelik tipi bulunamadı.")),
        );
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Gazete Aboneliği Seç",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = list[i];
                      final id = _toInt(item["id"]) ?? 0;
                      final months = _toInt(item["duration_months"]) ?? 0;
                      final price = _parsePrice(item["price"]);
                      final title = (item["title"] ?? "").toString().trim();
                      final displayTitle = title.isNotEmpty
                          ? title
                          : "$months Aylık Gazete Aboneliği";
                      final cartItem = CartItem(
                        id: "news-type-$id",
                        title: displayTitle,
                        subtitle: "Gazete Aboneliği",
                        imageUrl: imageUrl,
                        price: price,
                        quantity: 1,
                        type: CartItemType.newspaperSubscription,
                        metadata: {
                          "productId": id,
                          "period": months,
                          "periodMonths": months,
                          "typeTitle": displayTitle,
                        },
                      );
                      final alreadyInCart = cart.contains(cartItem);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(displayTitle),
                        subtitle: Text(
                          months > 0 ? "$months ay" : "Gazete Aboneliği",
                        ),
                        trailing: Text(
                          alreadyInCart
                              ? "Sepette"
                              : "₺${price.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: alreadyInCart ? Colors.grey : Colors.red,
                          ),
                        ),
                        onTap: alreadyInCart
                            ? null
                            : () {
                                final added = cart.addIfAbsent(cartItem);
                                if (added) {
                                  Navigator.pop(context);
                                  showAddedToCartDialog(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Bu ürün zaten sepette."),
                                    ),
                                  );
                                }
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gazete abonelik tipleri alınamadı: $e")),
      );
    }
  }

  void _openFromOrderItem(Map<String, dynamic> item) {
    final type = (item["product_type"] ?? "").toString();
    final meta = item["metadata"] as Map<String, dynamic>? ?? {};
    final productId =
        item["id"] ??
        item["product_id"] ??
        item["productId"] ??
        meta["product_id"] ??
        meta["id"];
    final fallbackFileUrl =
        meta["file_url"] ??
        meta["pdf_url"] ??
        meta["book_url"] ??
        item["file_url"] ??
        item["pdf_url"] ??
        item["book_url"];
    final mergedMeta = <String, dynamic>{
      ...meta,
      if (fallbackFileUrl != null && fallbackFileUrl.toString().isNotEmpty)
        "fileUrl": fallbackFileUrl,
    };

    Future<void> openPdf(String url, String title) async {
      try {
        await PdfOpenHelper.downloadAndOpen(
          context,
          url: url,
          title: title,
          isPrivate: true,
          showDialogProgress: true,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Dosya açılamadı: $e")));
      }
    }

    final pid = _toInt(productId);

    switch (type) {
      case "book":
        if (pid != null) {
          final local = books.firstWhere(
            (b) => b["id"] == pid,
            orElse: () => {},
          );
          if (local.isNotEmpty) {
            final baseDetail = _mapBookDetail(local);
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
            return;
          }
          _bookService.getBookById(pid).then((book) {
            final baseDetail = _mapBookDetail(book ?? {});
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
          });
          return;
        }
        break;
      case "magazine_issue":
        if (pid != null) {
          _magService.getIssueById(pid).then((issue) {
            final magId = issue?["magazine_id"] as int?;
            if (magId != null) {
              _magService.getMagazineById(magId).then((mag) {
                final baseDetail = _mapMagazineDetail(mag ?? {});
                final detail = baseDetail.copyWith(
                  forceAccess: true,
                  metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
                );
                _openProductDetail(detail);
              });
              return;
            }
            final name =
                issue?["magazine"]?["name"]?.toString() ?? "Dergi Sayısı";
            final issueNo = issue?["issue_number"]?.toString();
            final title = issueNo != null ? "$name - $issueNo" : name;
            final url =
                issue?["file_url"]?.toString() ?? meta["file_url"]?.toString();
            if (url != null && url.isNotEmpty) {
              openPdf(url, title);
            }
          });
          return;
        }
        break;
      case "magazine":
        if (pid != null) {
          final local = magazines.firstWhere(
            (m) => m["id"] == pid,
            orElse: () => {},
          );
          if (local.isNotEmpty) {
            final baseDetail = _mapMagazineDetail(local);
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
            return;
          }
          _magService.getMagazineById(pid).then((mag) {
            final baseDetail = _mapMagazineDetail(mag ?? {});
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
          });
          return;
        }
        break;
      case "newspaper_subscription":
      case "newspaper":
        if (pid != null) {
          final nw = newspapers.firstWhere(
            (n) => n["id"] == pid,
            orElse: () => {},
          );
          if (nw.isNotEmpty) {
            final baseDetail = _mapNewspaperDetail(nw);
            final detail = baseDetail.copyWith(
              forceAccess: true,
              metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
            );
            _openProductDetail(detail);
            return;
          }
        }
        if (newspapers.isNotEmpty) {
          final baseDetail = _mapNewspaperDetail(newspapers.first);
          final detail = baseDetail.copyWith(
            forceAccess: true,
            metadata: {...(baseDetail.metadata ?? {}), ...mergedMeta},
          );
          _openProductDetail(detail);
          return;
        }
        break;
      case "ek":
        _openEkDetail(item);
        return;
      default:
        break;
    }

    // Fallback: ürün detayı
    final detail = ProductDetail(
      id: "item-$productId",
      title: item["title"] ?? meta["title"] ?? "Ürün",
      description: meta["description"]?.toString() ?? "",
      imageUrl:
          meta["cover_image_url"]?.toString() ??
          meta["cover_url"]?.toString() ??
          "",
      price: _parsePrice(item["unit_price"] ?? item["line_total"]),
      type: CartItemType.book,
      metadata: {"productId": productId, ...mergedMeta},
      actionLabel: "Görüntüle",
      forceAccess: true,
    );
    _openProductDetail(detail);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _buildHomeShowcaseList({
    required List<Map<String, dynamic>> baseItems,
    required List<Map<String, dynamic>> selectedEntries,
    required int maxItems,
    required String idKey,
    required String selectedIdKey,
  }) {
    if (baseItems.isEmpty) return [];
    final selectedIds = <int>{};
    final result = <Map<String, dynamic>>[];

    for (final entry in selectedEntries) {
      if (result.length >= maxItems) break;
      final entryId = _toInt(entry[selectedIdKey]);
      if (entryId == null) continue;
      final item = baseItems.firstWhere(
        (i) => _toInt(i[idKey]) == entryId,
        orElse: () => {},
      );
      if (item.isEmpty) continue;
      selectedIds.add(entryId);
      result.add(item);
    }

    for (final item in baseItems) {
      if (result.length >= maxItems) break;
      final id = _toInt(item[idKey]);
      if (id == null || selectedIds.contains(id)) continue;
      result.add(item);
    }

    return result;
  }

  bool _hasPurchased(String type, int? itemId) {
    if (itemId == null) return false;
    if (_freeMagNews &&
        (type == "magazine" ||
            type == "newspaper_subscription" ||
            type == "newspaper" ||
            type == "magazine_issue")) {
      return true;
    }
    final access = context.read<AccessProvider>();
    if (access.hasAccess(type, itemId: itemId)) return true;
    if (libraryOrders.isEmpty) return false;
    final items = libraryOrders
        .expand<Map<String, dynamic>>(
          (o) => List<Map<String, dynamic>>.from(o["order_items"] ?? []),
        )
        .toList();
    return items.any((i) {
      final itemType = (i["product_type"] ?? "").toString();
      if (itemType != type) return false;
      final meta = i["metadata"] as Map<String, dynamic>? ?? {};
      final pid = _toInt(
        meta["product_id"] ?? meta["id"] ?? i["product_id"] ?? i["id"],
      );
      return pid == itemId;
    });
  }

  Future<_AccessItem> _resolveAccessItem(
    String type,
    Map<String, dynamic> entry,
  ) async {
    final itemId = entry["item_id"];
    switch (type) {
      case "ek":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen ek");
        final ek = await _ekService.getEk(itemId as int);
        final title = ek?["ad"]?.toString() ?? "Ek #$itemId";
        return _AccessItem(
          title: title,
          subtitle: "Ek",
          icon: _iconForType(type),
          onTap: (ek == null)
              ? null
              : () {
                  if (!mounted) return;
                  _openEkDetail(ek);
                },
        );
      case "book":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen kitap");
        final book = await _bookService.getBookById(itemId as int);
        final title = book?["title"]?.toString() ?? "Kitap #$itemId";
        final url = book?["book_url"]?.toString();
        return _AccessItem(
          title: title,
          subtitle: "Kitap",
          icon: _iconForType(type),
          onTap: (url == null || url.isEmpty)
              ? null
              : () async {
                  try {
                    await PdfOpenHelper.downloadAndOpen(
                      context,
                      url: url,
                      title: title,
                      isPrivate: true,
                      showDialogProgress: true,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Dosya açılamadı: $e")),
                    );
                  }
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
          icon: _iconForType(type),
          onTap: (url == null || url.isEmpty)
              ? null
              : () async {
                  try {
                    await PdfOpenHelper.downloadAndOpen(
                      context,
                      url: url,
                      title: "$magName - $issueNumber",
                      isPrivate: true,
                      showDialogProgress: true,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Dosya açılamadı: $e")),
                    );
                  }
                },
        );
      case "magazine":
        if (itemId == null) return _AccessItem(title: "Dergi aboneliği");
        final mag = await _magService.getMagazineById(itemId as int);
        final name = mag?["name"]?.toString() ?? "Dergi #$itemId";
        final expiresAtRaw = entry["expires_at"]?.toString();
        final expiresAt = expiresAtRaw == null
            ? null
            : DateTime.tryParse(expiresAtRaw);
        final subtitle = expiresAt != null
            ? "Bitiş Tarihi: ${_formatDateShort(expiresAt)}"
            : "Dergi aboneliği";
        return _AccessItem(
          title: name,
          subtitle: subtitle,
          icon: _iconForType(type),
          onTap: () => _openMagazineIssuesFromLibrary(itemId, name),
        );
      case "newspaper_subscription":
        final expiresAtRaw = entry["expires_at"]?.toString();
        final expiresAt = expiresAtRaw == null
            ? null
            : DateTime.tryParse(expiresAtRaw);
        return _AccessItem(
          title: "Gazete aboneliği",
          subtitle: expiresAt != null
              ? "Bitiş Tarihi: ${_formatDateShort(expiresAt)}"
              : (_freeMagNews ? "Ücretsiz" : "Abonelik aktif"),
          icon: _iconForType(type),
          onTap: null,
        );
      default:
        return _AccessItem(
          title: "Bilinmeyen içerik",
          icon: _iconForType(type),
        );
    }
  }

  Future<void> _openMagazineIssuesFromLibrary(
    int magazineId,
    String name,
  ) async {
    final issues = await _magService.getIssues(magazineId);
    if (!mounted) return;
    final access = context.read<AccessProvider>();
    final start = access.startDate("magazine", itemId: magazineId);
    final end = access.expiry("magazine", itemId: magazineId);
    final visibleIssues = _filterIssuesByPeriod(issues, start, end);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mq = MediaQueryData.fromView(View.of(sheetContext));
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        return SizedBox(
          height: mq.size.height,
          child: Padding(
            padding: EdgeInsets.only(
              top: mq.padding.top,
              bottom: viewInsets.bottom + mq.padding.bottom,
              left: 12,
              right: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$name Sayıları",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: visibleIssues.isEmpty
                      ? const Center(child: Text("Sayı bulunamadı"))
                      : ListView.separated(
                          itemCount: visibleIssues.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final issue = visibleIssues[i];
                            final title = "Sayı ${issue["issue_number"]}";
                            final imageUrl = issue["photo_url"]?.toString() ?? "";
                            return ListTile(
                              title: Text(title),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                final detail = _buildMagazineIssueDetail(
                                  issue: issue,
                                  issueNumber: title,
                                  magazineId: magazineId,
                                  magazineName: name,
                                  imageUrl: imageUrl,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(detail: detail),
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
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterIssuesByPeriod(
    List<Map<String, dynamic>> issues,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null || end == null) return issues;
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return issues.where((issue) {
      final raw = issue["added_at"]?.toString();
      if (raw == null || raw.isEmpty) return false;
      final added = DateTime.tryParse(raw);
      if (added == null) return false;
      final addedDay = DateTime(added.year, added.month, added.day);
      return !addedDay.isBefore(startDay) && !addedDay.isAfter(endDay);
    }).toList();
  }

  Future<void> _openAccessSheet(
    BuildContext context,
    String itemType,
    String title,
  ) async {
    if (_loadingAccessSheet) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loadingAccessSheet = true);
    List<Map<String, dynamic>> entries = [];
    try {
      entries = await _accessService.getAccess(
        userId: userId,
        itemType: itemType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erişim alınamadı: $e")));
      }
    } finally {
      if (mounted) setState(() => _loadingAccessSheet = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mq = MediaQueryData.fromView(View.of(sheetContext));
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        return SizedBox(
          height: mq.size.height,
          child: Padding(
            padding: EdgeInsets.only(
              top: mq.padding.top,
              bottom: viewInsets.bottom + mq.padding.bottom,
              left: 12,
              right: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _loadingAccessSheet
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                final data = snap.data!;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade100,
                                    foregroundColor: Colors.red,
                                    child: Icon(
                                      data.icon ?? _iconForType(itemType),
                                    ),
                                  ),
                                  title: Text(data.title),
                                  subtitle: data.subtitle != null
                                      ? Text(data.subtitle!)
                                      : null,
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
        );
      },
    );
  }

  Future<void> _openMagazineIssues(int magazineId) async {
    try {
      final issues = await _magService.getIssues(magazineId);
      if (!mounted) return;
      if (issues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu dergiye ait sayı bulunamadı.")),
        );
        return;
      }
      showModalBottomSheet(
        context: context,
        builder: (_) => ListView.separated(
          itemCount: issues.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final issue = issues[i];
            final num = issue["issue_number"]?.toString() ?? "#${issue["id"]}";
            return ListTile(
              leading: const Icon(Icons.auto_stories),
              title: Text("Sayı $num"),
              onTap: () {
                Navigator.pop(context);
                final url = issue["file_url"]?.toString();
                if (url != null && url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        url: url,
                        title: "Dergi Sayısı $num",
                        isPrivate: true,
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Dergi sayıları alınamadı: $e")));
    }
  }

  ProductDetail _buildMagazineIssueDetail({
    required Map<String, dynamic> issue,
    required String issueNumber,
    required int magazineId,
    required String magazineName,
    required String imageUrl,
  }) {
    final issueId = issue["id"] as int?;
    final title = issueNumber.isNotEmpty
        ? "$magazineName - $issueNumber"
        : "$magazineName - Sayı";
    final rawPrice = issue["price"];
    final price = _freeMagNews
        ? 0.0
        : (rawPrice is num ? rawPrice.toDouble() : _parsePrice(rawPrice));
    final description = (issue["description"] ?? "").toString().trim();
    final issueDate = issue["added_at"]?.toString() ??
        issue["publish_date"]?.toString() ??
        issue["created_at"]?.toString();
    final metadata = {
      "productId": issueId,
      "fileUrl": issue["file_url"]?.toString(),
      "magazineId": magazineId,
      "issueDate": issueDate,
    };
    return ProductDetail(
      id: "mag-issue-${issueId ?? issueNumber.hashCode}",
      title: title,
      subtitle: magazineName,
      description: description.isEmpty
          ? (_freeMagNews
              ? "Bu içerik ücretsiz olarak erişime açıktır."
              : "Bu dergi sayısına abonelik ile erişilir.")
          : description,
      imageUrl: UploadService.normalizeUrl(imageUrl),
      price: price,
      type: CartItemType.magazineIssue,
      metadata: metadata,
      actionLabel: "Sepete Ekle",
      forceAccess: _freeMagNews,
    );
  }

  ProductDetail _mapMagazineDetail(Map<String, dynamic> mag) {
    final hasAccess = _freeMagNews ||
        context.read<AccessProvider>().hasAccess(
          "magazine",
          itemId: mag["id"] as int?,
        );
    final actionLabel = hasAccess ? "E-dergiyi Gör" : "Abone Ol";
    return ProductDetail(
      id: "mag-${mag["id"]}",
      title: mag["name"] ?? "",
      subtitle: mag["category"] ?? "",
      description: mag["description"] ?? mag["category"] ?? "",
      imageUrl: mag["cover_image_url"] ?? "",
      price: 0,
      type: CartItemType.magazine,
      metadata: {
        "productId": mag["id"],
        "disableAdd": hasAccess,
        "fileUrl": mag["file_url"],
        "period": mag["period"],
      },
      actionLabel: actionLabel,
      forceAccess: _freeMagNews,
    );
  }

  ProductDetail _mapBookDetail(Map<String, dynamic> book) {
    final hasAccess = context.read<AccessProvider>().hasAccess(
      "book",
      itemId: book["id"] as int?,
    );
    final price = _effectiveBookPrice(book);
    final actionLabel = (hasAccess || price <= 0) ? "Kitabı Gör" : "Sepete Ekle";
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

  double _effectiveBookPrice(Map<String, dynamic> book) {
    final rawPrice = _parsePrice(book["price"]);
    final discPriceRaw = book["discount_price"];
    double price = rawPrice;
    if (discPriceRaw != null) {
      final dp = _parsePrice(discPriceRaw);
      if (dp < price) {
        price = dp;
      }
    }
    return price;
  }

  ProductDetail _mapNewspaperDetail(Map<String, dynamic> news) {
    final dateStr = news["publish_date"]?.toString() ?? "";
    final hasSub = _freeMagNews ||
        context.read<AccessProvider>().hasAccess(
          "newspaper_subscription",
        );
    final title = "E-Gazete";
    final fileUrl = news["file_url"]?.toString();
    return ProductDetail(
      id: "news-${news["id"] ?? "subscription"}",
      title: title,
      subtitle: dateStr,
      description: dateStr.isNotEmpty
          ? "Yayın tarihi: $dateStr"
          : "Günlük gazete aboneliği.",
      imageUrl: news["image_url"] ?? "",
      price: _freeMagNews ? 0.0 : 1.0,
      type: CartItemType.newspaperSubscription,
      metadata: {
        "productId": "gazete-abonelik",
        "disableAdd": hasSub,
        "fileUrl": fileUrl,
        "period": news["period"],
      },
      actionLabel: hasSub ? "Görüntüle" : "Abone Ol",
      forceAccess: _freeMagNews,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access provider'ı dinleyerek satın alınan içeriklerin UI'yi güncellemesini sağla
    context.watch<AccessProvider>();
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final hasSlider = sliders.isNotEmpty;
    final path = widget.initialUri?.path ?? "";
    final isPrivacyRoute = path == "/privacy" || path == "/privacy/";

    if (isPrivacyRoute) {
      return const PrivacyScreen();
    }

    if (loading || !_flagsLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 6,
        shadowColor: Colors.black.withOpacity(0.18),
        surfaceTintColor: Colors.white,
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
                            if (!_effectiveHideMagazines)
                              _menuItem("E-Dergi", HomeSection.magazines),
                            _menuItem("E-Kitap", HomeSection.books),
                            if (!_effectiveHideNewspapers)
                              _menuItem("E-Gazete", HomeSection.newspapers),
                            _menuItem("Ekler", HomeSection.attachments),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 0.5,
                                ),
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
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.black87,
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _cartCount(cart) > 0
                                    ? Colors.red
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _cartCount(cart).toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
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
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _mobileNavIndex == 2 && !isWeb
            ? _libraryView(context, this)
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _refreshHome,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                  constraints: const BoxConstraints(
                                    minHeight: 500,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_section == HomeSection.home) ...[
                                        if (hasSlider)
                                          _buildSlider(isWeb, isTablet),
                                        if (hasSlider)
                                          const SizedBox(height: 16),
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
                  ),
                ],
              ),
      ),
      bottomNavigationBar: isWeb
          ? null
          : Container(
              color: Colors.white,
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: BottomNavigationBar(
                  elevation: 12,
                  backgroundColor: Colors.white,
                  selectedItemColor: Colors.red,
                  unselectedItemColor: Colors.grey,
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _mobileNavIndex,
                  onTap: (index) {
                    setState(() => _mobileNavIndex = index);
                    if (index == 0) {
                      setState(() => _section = HomeSection.home);
                    }
                    if (index == 1) {
                      _openSearch();
                    }
                    if (index == 2) {
                      _loadLibraryOrders();
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
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      }
                    }
                  },
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: "Ana Sayfa",
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.search),
                      label: "Ara",
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.library_books_outlined),
                      label: "Kütüphanem",
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline),
                      label: auth.isLoggedIn ? "Profil" : "Giriş Yap",
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBodyContent(bool isWeb, bool isTablet, CartProvider cart) {
    switch (_section) {
      case HomeSection.magazines:
        if (_effectiveHideMagazines) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("E-dergi"),
            const SizedBox(height: 16),
            _magazineListGrid(context, isWeb),
          ],
        );
      case HomeSection.books:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("E-kitap"),
            const SizedBox(height: 16),
            _bookListGrid(context, isWeb, isTablet),
            const SizedBox(height: 24),
          ],
        );
      case HomeSection.newspapers:
        if (_effectiveHideNewspapers) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeadingText("E-Gazete"),
            const SizedBox(height: 12),
            _newspaperFilters(context),
            const SizedBox(height: 16),
            _newspaperListGrid(context, isWeb, _filteredNewspapers()),
          ],
        );
      case HomeSection.attachments:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isWeb)
                  IconButton(
                    onPressed: () =>
                        setState(() => _section = HomeSection.home),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: "Geri",
                  ),
                _sectionHeadingText("Ekler"),
              ],
            ),
            const SizedBox(height: 16),
            _attachmentsList(context, this, isWeb, cart),
          ],
        );
      case HomeSection.home:
      default:
        final hasNewspaperShowcase =
            !_effectiveHideNewspapers && newspapers.isNotEmpty;
        final hasMagazineShowcase =
            !_effectiveHideMagazines &&
            _buildHomeShowcaseList(
              baseItems: magazines,
              selectedEntries: homeMagazineEntries,
              maxItems: 10,
              idKey: "id",
              selectedIdKey: "product_id",
            ).isNotEmpty;
        final hasBookShowcase = _buildHomeShowcaseList(
          baseItems: books,
          selectedEntries: homeBookEntries,
          maxItems: 10,
          idKey: "id",
          selectedIdKey: "product_id",
        ).isNotEmpty;
        final hasEkSection = attachments.isNotEmpty;
        final hasAnyContent =
            sliders.isNotEmpty ||
            hasNewspaperShowcase ||
            hasMagazineShowcase ||
            hasBookShowcase ||
            hasEkSection;

        if (!hasAnyContent) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(
              child: Text(
                "İçerik bulunmamaktadır.",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        final children = <Widget>[];
        void addSection(Widget widget) {
          if (children.isNotEmpty) {
            children.add(const SizedBox(height: 32));
          }
          children.add(widget);
        }

        if (hasNewspaperShowcase) {
          addSection(_newspaperShowcase(context, isWeb, cart));
        }
        if (hasMagazineShowcase) {
          addSection(_magazineShowcase(context, isWeb));
        }
        if (hasBookShowcase) {
          addSection(_booksShowcase(context, isWeb, cart));
        }
        if (hasEkSection) {
          addSection(_homeEkSection(context, isWeb, cart));
        }

        if (children.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
    }
  }

  Widget _buildSlider(bool isWeb, bool isTablet) {
    if (sliders.isEmpty) return const SizedBox.shrink();
    final height = isWeb ? 360.0 : (isTablet ? 260.0 : 200.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _sliderController,
              itemCount: sliders.length,
              onPageChanged: (index) => setState(() => _sliderIndex = index),
              itemBuilder: (_, index) => _sliderSlide(sliders[index]),
            ),
          ),
        ),
        if (sliders.length > 1) ...[
          const SizedBox(height: 10),
          _buildSliderIndicators(),
        ],
      ],
    );
  }

  Widget _sliderSlide(Map<String, dynamic> slide) {
    final imageUrl = UploadService.normalizeUrl(
      slide["image_url"]?.toString() ?? "",
    );
    final title = slide["title"]?.toString() ?? "";
    final subtitle = slide["subtitle"]?.toString() ?? "";
    final hasOverlay = title.isNotEmpty || subtitle.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSliderTap(slide),
        child: Stack(
          fit: StackFit.expand,
          children: [
            safeImage(imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.image),
            if (hasOverlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
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

  Widget _buildSliderIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(sliders.length, (index) {
        final active = index == _sliderIndex;
        return GestureDetector(
          onTap: () {
            if (!_sliderController.hasClients) return;
            _sliderController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? Colors.red : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  Widget _magazineShowcase(BuildContext context, bool isWeb) {
    if (_effectiveHideMagazines) return const SizedBox.shrink();
    final displayList = _buildHomeShowcaseList(
      baseItems: magazines,
      selectedEntries: homeMagazineEntries,
      maxItems: 10,
      idKey: "id",
      selectedIdKey: "product_id",
    );
    if (displayList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Öne Çıkan E-dergi",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.magazines);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MagazineBrowseScreen(homeState: this),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isWeb ? 265 : 285,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final isSubscribed = _freeMagNews ||
                  _hasPurchased(
                    "magazine",
                    _toInt(displayList[i]["id"]),
                  );
              return _bookCard(
                {
                  "image": displayList[i]["cover_image_url"],
                  "title": displayList[i]["name"],
                  "author": displayList[i]["category"] ?? "",
                  "price": isWeb && !isSubscribed ? "Fiyat için tıkla" : "",
                  "statusLabel": _freeMagNews ? "Ücretsiz" : "Abonelik aktif",
                },
                isWeb,
                hideAction: isSubscribed,
                onAdd: () {
                  _openProductDetail(_mapMagazineDetail(displayList[i]));
                },
                onTap: () {
                  _openProductDetail(_mapMagazineDetail(displayList[i]));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _booksShowcase(BuildContext context, bool isWeb, CartProvider cart) {
    final access = context.watch<AccessProvider>();
    final displayList = _buildHomeShowcaseList(
      baseItems: books,
      selectedEntries: homeBookEntries,
      maxItems: 10,
      idKey: "id",
      selectedIdKey: "product_id",
    );
    if (displayList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Popüler E-kitap",
          onViewAll: () {
            if (isWeb) {
              setState(() => _section = HomeSection.books);
            } else {
              _openFullList(
                context,
                "E-kitap",
                (ctx) => _bookListGrid(ctx, false, false),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isWeb ? 285 : 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final effectivePrice = _effectiveBookPrice(displayList[i]);
              final item = CartItem(
                id: "book-${displayList[i]["id"]}",
                title: displayList[i]["title"] ?? "",
                subtitle: displayList[i]["author_rel"]?["name"] ?? "",
                imageUrl: displayList[i]["cover_url"] ?? "",
                price: effectivePrice,
                quantity: 1,
                type: CartItemType.book,
                metadata: {"productId": displayList[i]["id"]},
              );
              final alreadyInCart = cart.contains(item);
              final isFree = effectivePrice <= 0;
              final purchased = _hasPurchased(
                "book",
                _toInt(displayList[i]["id"]),
              );
              return _bookCard(
                {
                  "image": displayList[i]["cover_url"],
                  "title": displayList[i]["title"],
                  "author": displayList[i]["author_rel"]?["name"] ?? "-",
                  "salePrice": displayList[i]["price"],
                  "campaignPrice": displayList[i]["discount_price"],
                },
                isWeb,
                hideAction: purchased || isFree,
                onAdd: alreadyInCart || isFree
                    ? null
                    : () => _addToCart(context, cart, item),
                onTap: () {
                  _openProductDetail(_mapBookDetail(displayList[i]));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _newspaperShowcase(
    BuildContext context,
    bool isWeb,
    CartProvider cart,
  ) {
    if (_effectiveHideNewspapers) return const SizedBox.shrink();
    if (newspapers.isEmpty) return const SizedBox.shrink();
    final access = context.watch<AccessProvider>();
    const fallbackImage = "assets/images/gazete.jpg";
    final today = DateTime.now();
    final items = newspapers.take(10).map((n) {
      final dateStr = n["publish_date"]?.toString() ?? "";
      final d = DateTime.tryParse(dateStr);
      final label = d != null ? _formatDateTr(d) : dateStr;
      final titleText = label.isNotEmpty ? label : _formatDateTr(today);
      return {
        "image": n["image_url"] ?? fallbackImage,
        "date": "E-Gazete",
        "title": titleText,
        "raw": n,
      };
    }).toList();

    final showRead =
        _freeMagNews || access.hasAccess("newspaper_subscription");
    final subscriptionImage = items.isNotEmpty
        ? (items.first["image"] as String? ?? fallbackImage)
        : fallbackImage;

    void openList() {
      if (isWeb) {
        setState(() => _section = HomeSection.newspapers);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _NewspaperListScreen(homeState: this),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "E-Gazete",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                if (!showRead)
                  ElevatedButton(
                    onPressed: () {
                      _selectNewspaperSubscriptionType(
                        context,
                        cart,
                        imageUrl: subscriptionImage,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Abone Ol"),
                  ),
                if (!showRead) const SizedBox(width: 8),
                TextButton(
                  onPressed: openList,
                  child: const Text(
                    "Tümünü Gör",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isNotEmpty)
          SizedBox(
            height: isWeb ? 240 : (showRead ? 220 : 200),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _newspaperPreviewCard(
                items[i],
                width: isWeb ? 160 : 150,
                compact: true,
                imageHeight: showRead ? 120 : 135,
                showRead: showRead,
                onTap: () => _openProductDetail(
                  _mapNewspaperDetail(items[i]["raw"] as Map<String, dynamic>),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _newspaperFilters(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasSubscription =
        context.watch<AccessProvider>().hasAccess("newspaper_subscription");
    if (!_freeMagNews && (!auth.isLoggedIn || !hasSubscription)) {
      return const SizedBox.shrink();
    }
    Future<void> pickSingleDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(2000),
        lastDate: now.add(const Duration(days: 365 * 2)),
        locale: const Locale('tr', 'TR'),
      );
      if (picked == null) return;
      final normalized = _normalizeDate(picked);
      final dateLabel =
          "${normalized.day.toString().padLeft(2, "0")}.${normalized.month.toString().padLeft(2, "0")}.${normalized.year}";
      final pdfUrl = _legacyNewspaperUrl(normalized);
      debugPrint("E-gazete PDF URL (tarih seçimi): $pdfUrl");
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: pdfUrl,
            title: "E-Gazete $dateLabel",
            isPrivate: false,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: pickSingleDate,
              icon: const Icon(Icons.event),
              label: const Text("Tarih Seç"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _homeEkSection(BuildContext context, bool isWeb, CartProvider cart) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final list = attachments.take(isWeb ? 5 : 4).toList();
    final viewportHeight = max(0.0, MediaQuery.of(context).size.height);
    final maxCardHeight = viewportHeight * (isWeb ? 0.32 : 0.35);
    final height = min(isWeb ? 299.0 : 259.0, maxCardHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Ekler",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                if (isWeb) {
                  setState(() => _section = HomeSection.attachments);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _AttachmentListScreen(state: this, cart: cart),
                    ),
                  );
                }
              },
              child: const Text(
                "Tümünü Gör",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final ek = list[i];
              final price = _parsePrice(ek["fiyat"]);
              final title = (ek["ad"] ?? "").toString();
              final desc = (ek["aciklama"] ?? "").toString();
              final imageUrl = UploadService.normalizeUrl(
                ek["photo_url"]?.toString() ?? "",
              );
              final isFree = price == 0;
              return SizedBox(
                width: isWeb ? 320 : 260,
                child: InkWell(
                  onTap: () => _openEkDetail(ek),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: safeImage(
                                imageUrl,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.broken_image,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title.isNotEmpty ? title : "Ek",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc.isNotEmpty ? desc : "Ek açıklaması",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isFree
                                  ? "Ücretsiz"
                                  : "₺${price.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _openEkDetail(ek),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: const Text("Detay"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _magazineListGrid(BuildContext context, bool isWeb) {
    if (_effectiveHideMagazines) return const SizedBox.shrink();
    final cart = Provider.of<CartProvider>(context, listen: false);
    final access = Provider.of<AccessProvider>(context, listen: false);
    final crossAxisCount = isWeb ? 4 : (isTabletLayout(context) ? 2 : 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 16.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final titleHeight = textScaler.scale(16) * 1.25; // 1 line
        final descHeight = textScaler.scale(13) * 1.25 * 2; // 2 lines
        final rowHeight = max(
          textScaler.scale(15) * 1.4,
          40.0,
        ); // price/button row
        const verticalGaps = 4 + 8; // SizedBox heights in card
        const contentPadding = 12 * 2; // Padding.all(12)
        const imageHeight = 170.0;
        const safetyMargin = 12.0;
        final cardHeight =
            imageHeight +
            contentPadding +
            verticalGaps +
            titleHeight +
            descHeight +
            rowHeight +
            safetyMargin;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 16,
            mainAxisExtent: cardHeight,
          ),
          itemCount: magazines.length,
          itemBuilder: (_, i) {
            final hideAction = !_freeMagNews &&
                _hasPurchased(
                  "magazine",
                  _toInt(magazines[i]["id"]),
                );
            return _magazineCard(
              {
                "image": magazines[i]["cover_image_url"],
                "title": magazines[i]["name"],
                "desc": magazines[i]["description"] ?? magazines[i]["category"],
                "price": _freeMagNews ? "Ücretsiz" : "",
              },
              hideAction: hideAction,
              onAdd: _freeMagNews || hideAction
                  ? null
                  : () {
                      _openProductDetail(_mapMagazineDetail(magazines[i]));
                    },
              onTap: () {
                _openProductDetail(_mapMagazineDetail(magazines[i]));
              },
            );
          },
        );
      },
    );
  }

  Widget _bookListGrid(BuildContext context, bool isWeb, bool isTablet) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final access = context.watch<AccessProvider>();
    final crossAxisCount = isWeb ? 4 : (isTablet ? 3 : 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final titleHeight = textScaler.scale(15) * 1.25 * 2; // 2 lines
        final authorHeight = textScaler.scale(12) * 1.25; // 1 line
        final rowHeight = 28.0; // add button + price row
        const verticalGaps = 4.0; // SizedBox height between title/author
        const contentPadding = 10.0 * 2; // Padding.all(10)
        const imageHeight = 150.0;
        final cardHeight =
            imageHeight +
            contentPadding +
            verticalGaps +
            titleHeight +
            authorHeight +
            rowHeight;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: books.length,
          itemBuilder: (_, i) {
            final effectivePrice = _effectiveBookPrice(books[i]);
            final item = CartItem(
              id: "book-${books[i]["id"]}",
              title: books[i]["title"] ?? "",
              subtitle: books[i]["author_rel"]?["name"] ?? "",
              imageUrl: books[i]["cover_url"] ?? "",
              price: effectivePrice,
              quantity: 1,
              type: CartItemType.book,
              metadata: {"productId": books[i]["id"]},
            );
            final alreadyInCart = cart.contains(item);
            return _bookCard(
              {
                "image": books[i]["cover_url"],
                "title": books[i]["title"],
                "author": books[i]["author_rel"]?["name"] ?? "-",
                "salePrice": books[i]["price"],
                "campaignPrice": books[i]["discount_price"],
              },
              isWeb,
              hideAction: _hasPurchased("book", _toInt(books[i]["id"])) ||
                  effectivePrice <= 0,
              onAdd: alreadyInCart || effectivePrice <= 0
                  ? null
                  : () => _addToCart(context, cart, item),
              onTap: () {
                _openProductDetail(_mapBookDetail(books[i]));
              },
            );
          },
        );
      },
    );
  }

  Widget _newspaperListGrid(
    BuildContext context,
    bool isWeb,
    List<Map<String, dynamic>> items,
  ) {
    if (_effectiveHideNewspapers) return const SizedBox.shrink();
    final crossAxisCount = isWeb ? 3 : 2;
    final hasSub = _freeMagNews ||
        Provider.of<AccessProvider>(
          context,
          listen: false,
        ).hasAccess("newspaper_subscription");
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: isWeb ? (hasSub ? 280 : 260) : (hasSub ? 210 : 195),
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final dateStr = items[i]["publish_date"]?.toString() ?? "";
            final dt = DateTime.tryParse(dateStr);
            final label = dt != null ? _formatDateTr(dt) : dateStr;
            final title = label.isNotEmpty ? label : "Gazete";
            return _newspaperPreviewCard(
              {
                "image": items[i]["image_url"],
                "title": title,
                "date": "E-Gazete",
              },
              compact: true,
              imageHeight: isWeb ? (hasSub ? 150 : 140) : (hasSub ? 130 : 120),
              showRead: _freeMagNews ||
                  context.read<AccessProvider>().hasAccess(
                    "newspaper_subscription",
                  ),
              onTap: () => _openProductDetail(_mapNewspaperDetail(items[i])),
            );
          },
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case "book":
        return Icons.menu_book_rounded;
      case "magazine":
        return Icons.auto_stories_rounded;
      case "magazine_issue":
        return Icons.chrome_reader_mode_outlined;
      case "newspaper_subscription":
        return Icons.newspaper;
      case "ek":
        return Icons.file_present;
      default:
        return Icons.article_outlined;
    }
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
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      TextButton(
        onPressed: onViewAll,
        child: const Text(
          "Tümünü Gör",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
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

Widget _priceWidgetForItem(
  Map<String, dynamic> item, {
  required TextStyle saleStyle,
  required TextStyle campaignStyle,
  String emptyText = "-",
}) {
  if (item.containsKey("salePrice") || item.containsKey("campaignPrice")) {
    final info = PriceInfo.fromRaw(item["salePrice"], item["campaignPrice"]);
    return buildPriceText(
      info: info,
      saleStyle: saleStyle,
      campaignStyle: campaignStyle,
      emptyText: emptyText,
    );
  }
  final fallback = item["price"]?.toString() ?? emptyText;
  return Text(fallback, style: campaignStyle);
}

Widget _magazineCard(
  Map<String, dynamic> item, {
  VoidCallback? onAdd,
  VoidCallback? onTap,
  bool hideAction = false,
}) {
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
                Text(
                  item["title"] ?? "",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    Expanded(
                      child: _priceWidgetForItem(
                        item,
                        saleStyle: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        campaignStyle: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hideAction)
                      const Text(
                        "Abonelik aktif",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    else if (onAdd != null)
                      ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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

Widget _bookCard(
  Map<String, dynamic> item,
  bool isWeb, {
  VoidCallback? onAdd,
  VoidCallback? onTap,
  bool hideAction = false,
}) {
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
            child: _imageWidget(item["image"], height: isWeb ? 140 : 150),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 8 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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
                      _priceWidgetForItem(
                        item,
                        saleStyle: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        campaignStyle: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hideAction && item["statusLabel"] != null)
                        Text(
                          item["statusLabel"].toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        )
                      else if (!hideAction)
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Material(
                            color: onAdd == null ? Colors.grey : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: onAdd,
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
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

Widget _newspaperCard(Map<String, dynamic> item, {VoidCallback? onTap}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item["title"] ?? "",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: safeImage(
                  UploadService.normalizeUrl(item["icon"]?.toString() ?? ""),
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.broken_image,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _newspaperPreviewCard(
  Map<String, dynamic> item, {
  VoidCallback? onTap,
  double? width,
  double? imageHeight,
  bool compact = false,
  bool showRead = false,
}) {
  final title = item["title"]?.toString() ?? "";
  final date = item["date"]?.toString() ?? "";
  final imageUrl = UploadService.normalizeUrl(item["image"]?.toString() ?? "");

  final resolvedImageHeight = imageHeight ?? (compact ? 135 : 210);

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: width,
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
            child: SizedBox(
              height: resolvedImageHeight,
              width: double.infinity,
              child: safeImage(
                imageUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.broken_image,
              ),
            ),
          ),
          if (compact)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (showRead) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Oku",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (showRead)
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text("Oku"),
                        ),
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
    "Aralık",
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  return "$day $month $year";
}

String _formatDateIso(DateTime date) {
  final y = date.year.toString().padLeft(4, "0");
  final m = date.month.toString().padLeft(2, "0");
  final d = date.day.toString().padLeft(2, "0");
  return "$y-$m-$d";
}

String _formatDateShort(DateTime date) {
  final day = date.day.toString().padLeft(2, "0");
  final month = date.month.toString().padLeft(2, "0");
  final year = date.year.toString();
  return "$day.$month.$year";
}

String _legacyNewspaperToken(String fileName) {
  const secret = "ya-X4qrNx9VwBK81sw2-";
  final slice = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 ~/ 600;
  final key = utf8.encode(secret + fileName);
  final hmac = Hmac(sha256, key);
  final bytes = ByteData(8)..setInt64(0, slice, Endian.little);
  final digest = hmac.convert(bytes.buffer.asUint8List());
  final hex = digest.toString().toUpperCase();
  return hex.substring(0, 16);
}

String _legacyNewspaperUrl(DateTime date) {
  final fileName = "${_formatDateIso(date)}.pdf";
  final token = _legacyNewspaperToken(fileName);
  return "https://www.yeniasya.com.tr/e-gazete/content/0/$token/$fileName";
}

int _cartCount(CartProvider cart) {
  return cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
}

void _addToCart(BuildContext context, CartProvider cart, CartItem item) {
  final auth = context.read<AuthProvider>();
  if (!auth.isLoggedIn) {
    showLoginRequirementDialog(context);
    return;
  }
  final added = cart.addIfAbsent(item);
  if (added) {
    showAddedToCartDialog(context);
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Bu ürün zaten sepette.")));
  }
}

Widget _libraryView(BuildContext context, _HomeResponsiveScreenState state) {
  final auth = context.watch<AuthProvider>();

  if (!auth.isLoggedIn) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text("Kütüphaneyi görmek için üye girişi yapmalısınız."),
      ),
    );
  }

  if (state.libraryLoading && state.libraryOrders.isEmpty) {
    return const Center(child: CircularProgressIndicator());
  }

  return RefreshIndicator(
    onRefresh: () async {
      await state._loadLibraryAccess();
      await state._loadLibraryOrders();
    },
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            state._storeFlagEnabled
                ? "İçerikler"
                : "Aboneliklerim / İçeriklerim",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        _librarySubscriptionCard(context, state),
      ],
    ),
  );
}

Widget _librarySubscriptionCard(
  BuildContext context,
  _HomeResponsiveScreenState state,
) {
  final showMag = !state._effectiveHideMagazines;
  final showNews = !state._effectiveHideNewspapers;
  final tiles = <Widget>[
    _libraryMenuTile(
      Icons.menu_book_outlined,
      "Kitaplar",
      onTap: () => state._openAccessSheet(context, "book", "Kitaplar"),
    ),
  ];
  if (showMag) {
    tiles.addAll([
      const Divider(height: 1, thickness: 1),
      _libraryMenuTile(
        Icons.library_books,
        "Dergi Abonelikleri",
        onTap: () =>
            state._openAccessSheet(context, "magazine", "Dergi Abonelikleri"),
      ),
      const Divider(height: 1, thickness: 1),
      _libraryMenuTile(
        Icons.history_edu,
        "Dergi Sayıları",
        onTap: () =>
            state._openAccessSheet(context, "magazine_issue", "Dergi Sayıları"),
      ),
    ]);
  }
  if (showNews) {
    tiles.addAll([
      const Divider(height: 1, thickness: 1),
      _libraryMenuTile(
        Icons.newspaper,
        "Gazete Aboneliği",
        onTap: () => state._openAccessSheet(
          context,
          "newspaper_subscription",
          "Gazete Aboneliği",
        ),
      ),
    ]);
  }
  tiles.addAll([
    const Divider(height: 1, thickness: 1),
    _libraryMenuTile(
      Icons.file_present,
      "Ekler",
      onTap: () => state._openAccessSheet(context, "ek", "Ekler"),
    ),
  ]);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: tiles),
    ),
  );
}

Widget _libraryMenuTile(IconData icon, String text, {VoidCallback? onTap}) {
  return ListTile(
    leading: Icon(icon, color: Colors.black54),
    title: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap ?? () {},
  );
}

Widget _libraryOrderCard(BuildContext context, Map<String, dynamic> order) {
  final id = order["id"]?.toString() ?? "-";
  final total = order["total_paid"]?.toString() ?? "0";
  final status = (order["status"] ?? "").toString().toLowerCase();
  final date = order["created_at"]?.toString() ?? "";

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order["id"] as int),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sipariş #$id",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(status),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Toplam",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                "₺$total",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _librarySection(
  BuildContext context,
  _HomeResponsiveScreenState state,
  String title,
  List<Map<String, dynamic>> items,
) {
  String itemTitle(Map<String, dynamic> item) {
    final metadata = Map<String, dynamic>.from(
      item["metadata"] as Map<String, dynamic>? ?? {},
    );
    final value =
        item["title"] ??
        metadata["title"] ??
        metadata["name"] ??
        metadata["ad"] ??
        item["ad"] ??
        "-";
    return value.toString();
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
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
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text("Bulunamadı.", style: TextStyle(color: Colors.black54))
        else
          ...items.map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.red.shade400,
                child: Icon(
                  state._iconForType((i["product_type"] ?? "").toString()),
                ),
              ),
              title: Text(
                itemTitle(i),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                state._openFromOrderItem(i);
              },
            ),
          ),
      ],
    ),
  );
}

Widget _attachmentsList(
  BuildContext context,
  _HomeResponsiveScreenState state,
  bool isWeb,
  CartProvider cart,
) {
  final access = context.watch<AccessProvider>();

  if (state.loading) {
    return const Center(child: CircularProgressIndicator());
  }
  if (state.attachments.isEmpty) {
    return const Text("Henüz ek bulunmuyor.");
  }

  final crossAxisCount = isWeb ? 3 : 1;
  final ratio = isWeb ? 3 / 1.2 : 3 / 1.8;

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: ratio,
    ),
    itemCount: state.attachments.length,
    itemBuilder: (_, i) {
      final ek = state.attachments[i];
      final price = state._parsePrice(ek["fiyat"]);
      final isFree = price == 0;
      final ekId = state._toInt(ek["id"]);
      final hasAccess = ekId != null && access.hasAccess("ek", itemId: ekId);
      final imageUrl = UploadService.normalizeUrl(
        ek["photo_url"]?.toString() ?? "",
      );

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: safeImage(
                imageUrl,
                width: 120,
                height: double.infinity,
                fit: BoxFit.cover,
                fallbackIcon: Icons.image_not_supported,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ek["ad"]?.toString() ?? "-",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (ek["aciklama"] ?? "").toString().isEmpty
                        ? "Açıklama yok"
                        : (ek["aciklama"] ?? "").toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _statusChip(
                        isFree ? "Ücretsiz" : "Ücretli",
                        isFree ? Colors.green : Colors.red,
                      ),
                      if (!isFree) ...[
                        const SizedBox(width: 10),
                        Text(
                          "₺${price.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => state._openEkDetail(ek),
                    child: const Text("Detay"),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AttachmentListScreen extends StatelessWidget {
  final _HomeResponsiveScreenState state;
  final CartProvider cart;

  const _AttachmentListScreen({required this.state, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ekler")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _attachmentsList(context, state, false, cart),
      ),
    );
  }
}

class _NewspaperListScreen extends StatefulWidget {
  final _HomeResponsiveScreenState homeState;

  const _NewspaperListScreen({required this.homeState});

  @override
  State<_NewspaperListScreen> createState() => _NewspaperListScreenState();
}

class _NewspaperListScreenState extends State<_NewspaperListScreen> {
  Future<void> _pickSingleDate() async {
    final auth = context.read<AuthProvider>();
    final access = context.read<AccessProvider>();
    final canPick =
        widget.homeState._freeMagNews ||
        (auth.isLoggedIn && access.hasAccess("newspaper_subscription"));
    if (!canPick) {
      if (!auth.isLoggedIn) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("E-gazete aboneliği gerekli.")),
        );
      }
      return;
    }
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365 * 2)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null) return;
    final normalized = DateTime(picked.year, picked.month, picked.day);
    final dateLabel =
        "${normalized.day.toString().padLeft(2, "0")}.${normalized.month.toString().padLeft(2, "0")}.${normalized.year}";
    final pdfUrl = _legacyNewspaperUrl(normalized);
    debugPrint("E-gazete PDF URL (tarih seçimi - mobil): $pdfUrl");
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: pdfUrl,
          title: "E-Gazete $dateLabel",
          isPrivate: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasSubscription =
        context.watch<AccessProvider>().hasAccess("newspaper_subscription");
    final canPickDate =
        widget.homeState._freeMagNews || (auth.isLoggedIn && hasSubscription);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("E-Gazete"),
        elevation: 1,
        actions: [
          if (canPickDate)
            TextButton.icon(
              onPressed: _pickSingleDate,
              icon: const Icon(Icons.event, size: 20),
              label: const Text("Tarih Seç"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.homeState._newspaperListGrid(
                context,
                false,
                widget.homeState.newspapers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case "pending":
      return "Beklemede";
    case "paid":
      return "Ödendi";
    case "shipped":
      return "Kargoda";
    case "delivered":
      return "Teslim Edildi";
    case "canceled":
      return "İptal";
    case "refunded":
      return "İade";
    default:
      return status.isEmpty ? "-" : status;
  }
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

Widget _statusChip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _MagazineBrowseScreen extends StatefulWidget {
  final _HomeResponsiveScreenState homeState;

  const _MagazineBrowseScreen({required this.homeState});

  @override
  State<_MagazineBrowseScreen> createState() => _MagazineBrowseScreenState();
}

class _MagazineBrowseScreenState extends State<_MagazineBrowseScreen> {
  final Map<int, Future<List<Map<String, dynamic>>>> _issuesFutures = {};

  Future<List<Map<String, dynamic>>> _issuesFor(int magazineId) {
    return _issuesFutures.putIfAbsent(
      magazineId,
      () async => widget.homeState._magService.getIssues(magazineId),
    );
  }

  DateTime? _issueDate(Map<String, dynamic> issue) {
    final raw =
        issue["added_at"]?.toString() ?? issue["created_at"]?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isWithinAccessWindow({
    required DateTime issueDate,
    required DateTime start,
    required DateTime end,
  }) {
    final issueDay = DateTime(issueDate.year, issueDate.month, issueDate.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !issueDay.isBefore(startDay) && !issueDay.isAfter(endDay);
  }

  Widget _magazineCard(BuildContext context, Map<String, dynamic> mag) {
    final title = (mag["name"] ?? "-").toString();
    final imageUrl = UploadService.normalizeUrl(
      (mag["cover_image_url"] ?? "").toString(),
    );
    return InkWell(
      onTap: () => widget.homeState._openProductDetail(
        widget.homeState._mapMagazineDetail(mag),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 150,
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: safeImage(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                fallbackIcon: Icons.auto_stories,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueCard({
    required BuildContext context,
    required Map<String, dynamic> mag,
    required Map<String, dynamic> issue,
  }) {
    final issueNumber = (issue["issue_number"] ?? "").toString();
    final label = issueNumber.isEmpty ? "Sayı" : "Sayı $issueNumber";
    final photo = (issue["photo_url"] ?? mag["cover_image_url"] ?? "")
        .toString();
    final imageUrl = UploadService.normalizeUrl(photo);
    final fileUrl = (issue["file_url"] ?? "").toString();

    return Container(
      width: 150,
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
            child: safeImage(
              imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              fallbackIcon: Icons.auto_stories,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      final detail = widget.homeState._buildMagazineIssueDetail(
                        issue: issue,
                        issueNumber: label,
                        magazineId: widget.homeState._toInt(mag["id"]) ?? 0,
                        magazineName: (mag["name"] ?? "").toString(),
                        imageUrl: photo,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(detail: detail),
                        ),
                      );
                    },
                    child: const Text("Detay"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final mags = widget.homeState.magazines;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("E-dergi"),
        elevation: 1,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: mags.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, i) {
            final mag = mags[i];
            final magId = widget.homeState._toInt(mag["id"]);
            if (magId == null) return const SizedBox.shrink();

            final start = access.startDate("magazine", itemId: magId);
            final end = access.expiry("magazine", itemId: magId);
            final hasMagazineAccess = access.hasAccess(
              "magazine",
              itemId: magId,
            );

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _issuesFor(magId),
              builder: (context, snap) {
                final issues = snap.data ?? const <Map<String, dynamic>>[];

                return SizedBox(
                  height: 238,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 1 + issues.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, idx) {
                      if (idx == 0) return _magazineCard(context, mag);
                      final issue = issues[idx - 1];
                      final issueId = widget.homeState._toInt(issue["id"]);
                      final directIssueAccess = access.hasAccess(
                        "magazine_issue",
                        itemId: issueId,
                      );
                      final issueDate = _issueDate(issue);
                      final windowAccess =
                          hasMagazineAccess &&
                          start != null &&
                          end != null &&
                          issueDate != null &&
                          _isWithinAccessWindow(
                            issueDate: issueDate,
                            start: start,
                            end: end,
                          );
                      return _issueCard(
                        context: context,
                        mag: mag,
                        issue: issue,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AccessItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;

  _AccessItem({required this.title, this.subtitle, this.icon, this.onTap});
}
