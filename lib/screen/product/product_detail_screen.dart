import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/cart_item.dart';
import '../../services/cart/cart_provider.dart';
import '../../utils/safe_image.dart';
import 'magazine_issues_screen.dart';
import '../../services/upload_service.dart';
import '../../services/magazine_type_price_service.dart';
import '../../services/newspaper_subscription_type_service.dart';
import '../../services/access_provider.dart';
import '../../services/review_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/revenuecat_service.dart';
import '../../utils/cart_feedback.dart';
import 'package:flutter/foundation.dart';
import '../../utils/pdf_open_helper.dart';
import '../../services/secure_file_service.dart';
import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/admin/admin_newspaper_service.dart';

class ProductDetail {
  final String id;
  final String title;
  final String? subtitle;
  final String description;
  final String imageUrl;
  final double price;
  final CartItemType type;
  final Map<String, dynamic>? metadata;
  final String actionLabel;
  final bool forceAccess;

  const ProductDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.type,
    required this.actionLabel,
    this.subtitle,
    this.metadata,
    this.forceAccess = false,
  });

  String get priceText =>
      price > 0 ? "₺${price.toStringAsFixed(2)}" : "Ücretsiz";

  ProductDetail copyWith({bool? forceAccess, Map<String, dynamic>? metadata}) {
    return ProductDetail(
      id: id,
      title: title,
      subtitle: subtitle,
      description: description,
      imageUrl: imageUrl,
      price: price,
      type: type,
      actionLabel: actionLabel,
      metadata: metadata ?? this.metadata,
      forceAccess: forceAccess ?? this.forceAccess,
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final ProductDetail detail;

  const ProductDetailScreen({super.key, required this.detail});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const int _reviewCommentMaxLength = 1000;

  final _reviewService = ReviewService();
  final _magazineTypePriceService = MagazineTypePriceService();
  final _newspaperTypePriceService = NewspaperSubscriptionTypeService();
  final _bookService = AdminBookService();
  final _magazineService = AdminMagazineService();
  final _newspaperService = AdminNewspaperService();
  final TextEditingController _commentCtrl = TextEditingController();
  int _rating = 5;
  bool _reviewSubmitting = false;
  bool _reviewsLoading = false;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  int _reviewCount = 0;
  bool _hasLocalCopy = false;
  bool _downloadBusy = false;
  bool _openingBook = false;
  double? _downloadProgress;
  String? _resolvedFileUrl;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkLocalCopy();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _addToCart(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequirementDialog(context);
      return;
    }
    if (widget.detail.type == CartItemType.magazineIssue &&
        _hasDirectMagazineIssueAccess(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu sayıya zaten sınırsız erişiminiz bulunuyor."),
        ),
      );
      return;
    }
    final cart = context.read<CartProvider>();
    final item = CartItem(
      id: widget.detail.id,
      title: widget.detail.title,
      subtitle: widget.detail.subtitle,
      imageUrl: widget.detail.imageUrl,
      price: widget.detail.price,
      quantity: 1,
      type: widget.detail.type,
      metadata: widget.detail.metadata,
    );
    final added = cart.addIfAbsent(item);
    if (added) {
      showAddedToCartDialog(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Bu ürün zaten sepette.")));
    }
  }

  Future<void> _openNewspaperPaywall(BuildContext context) async {
    if (widget.detail.forceAccess) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (!auth.isLoggedIn || user == null) {
      showLoginRequirementDialog(
        context,
        message:
            "E-gazeteye abone olmak için üye girişi yapmanız gerekmektedir.",
      );
      return;
    }

    final rc = context.read<RevenueCatService>();
    if (!rc.supportsNativePurchaseUi) {
      await _selectNewspaperSubscriptionType(context);
      return;
    }
    final access = context.read<AccessProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await rc.syncWithAuthUser(user);
    final result = await rc.presentYeniasyaProPaywall(userId: user.id);
    if (!mounted) return;

    if (result.name == "purchased" || result.name == "restored") {
      await access.load(user.id, force: true);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Abonelik başarıyla aktif edildi.")),
      );
      return;
    }
    if (result.name == "notPresented" && rc.isYeniasyaProActive) {
      await access.load(user.id, force: true);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Aboneliğiniz zaten aktif.")),
      );
      return;
    }
    if (result.name == "cancelled") {
      messenger.showSnackBar(
        const SnackBar(content: Text("İşlem iptal edildi.")),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(rc.errorMessage ?? "Abonelik işlemi tamamlanamadı."),
      ),
    );
  }

  Future<void> _selectNewspaperSubscriptionType(BuildContext context) async {
    if (widget.detail.forceAccess) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequirementDialog(context);
      return;
    }
    try {
      final list = await _newspaperTypePriceService.getActiveTypes();
      if (!mounted) return;
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gazete abonelik seçenekleri bulunamadı."),
          ),
        );
        return;
      }
      final cart = context.read<CartProvider>();
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
                  "E-Gazete Aboneliği Seç",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final type = list[i];
                      final typeId =
                          int.tryParse(type["id"]?.toString() ?? "") ?? 0;
                      final months =
                          int.tryParse(
                            type["duration_months"]?.toString() ?? "",
                          ) ??
                          0;
                      final price =
                          double.tryParse(type["price"]?.toString() ?? "") ?? 0;
                      final title = (type["title"] ?? "").toString().trim();
                      final displayTitle = title.isNotEmpty
                          ? title
                          : (months > 0
                                ? "$months Aylık Abonelik"
                                : "Abonelik");
                      final cartItem = CartItem(
                        id: "news-sub-type-$typeId",
                        title: widget.detail.title,
                        subtitle: displayTitle,
                        imageUrl: widget.detail.imageUrl,
                        price: price,
                        quantity: 1,
                        type: CartItemType.newspaperSubscription,
                        metadata: {
                          ...?widget.detail.metadata,
                          "productId": "gazete-abonelik",
                          "newspaperSubscriptionTypeId": typeId,
                          "periodMonths": months,
                          "period": months > 0 ? months.toString() : null,
                          "typeTitle": displayTitle,
                        },
                      );
                      final alreadyInCart = cart.contains(cartItem);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(displayTitle),
                        subtitle: Text(
                          months > 0 ? "$months ay" : "E-Gazete Aboneliği",
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
        SnackBar(content: Text("Abonelik seçenekleri alınamadı: $e")),
      );
    }
  }

  Future<void> _selectMagazineSubscriptionType(
    BuildContext context,
    int magazineId,
  ) async {
    if (widget.detail.forceAccess) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequirementDialog(context);
      return;
    }
    try {
      final list = await _magazineTypePriceService.getActiveByMagazine(
        magazineId,
      );
      if (!mounted) return;
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dergi abonelik tipi bulunamadı.")),
        );
        return;
      }
      final cart = context.read<CartProvider>();
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
                  "Dergi Aboneliği Seç",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = list[i];
                      final type =
                          item["magazine_type"] as Map<String, dynamic>? ?? {};
                      final typeId =
                          int.tryParse(type["id"]?.toString() ?? "") ?? 0;
                      final months =
                          int.tryParse(
                            type["duration_months"]?.toString() ?? "",
                          ) ??
                          0;
                      final price =
                          double.tryParse(item["price"]?.toString() ?? "") ?? 0;
                      final title = (type["title"] ?? "").toString().trim();
                      final displayTitle = title.isNotEmpty
                          ? title
                          : "$months Aylık Dergi Aboneliği";
                      final cartItem = CartItem(
                        id: "mag-$magazineId-type-$typeId",
                        title: widget.detail.title,
                        subtitle: displayTitle,
                        imageUrl: widget.detail.imageUrl,
                        price: price,
                        quantity: 1,
                        type: CartItemType.magazine,
                        metadata: {
                          "productId": magazineId,
                          "magazineTypeId": typeId,
                          "magazineTypePriceId": item["id"],
                          "periodMonths": months,
                          "typeTitle": displayTitle,
                        },
                      );
                      final alreadyInCart = cart.contains(cartItem);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(displayTitle),
                        subtitle: Text(
                          months > 0 ? "$months ay" : "Dergi Aboneliği",
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
        SnackBar(content: Text("Dergi abonelik tipleri alınamadı: $e")),
      );
    }
  }

  bool _hasContentAccess(BuildContext context) {
    if (widget.detail.forceAccess) return true;
    final auth = context.read<AuthProvider>();
    final isSubscription = _isSubscriptionType(widget.detail.type);
    if (!auth.isLoggedIn) {
      if (widget.detail.price <= 0 && !isSubscription) {
        return true;
      }
      return false;
    }
    if (widget.detail.price <= 0 && !isSubscription) return true;
    if (_hasLocalCopy) return true;
    if (widget.detail.type == CartItemType.newspaperSubscription) {
      final access = context.read<AccessProvider>();
      final rc = context.read<RevenueCatService>();
      return access.hasAccess("newspaper_subscription") ||
          rc.isYeniasyaProActive;
    }
    if (widget.detail.type == CartItemType.magazineIssue) {
      final directIssueAccess = _hasDirectMagazineIssueAccess(context);
      final windowAccess = _hasMagazineIssueSubscriptionWindowAccess(context);
      return directIssueAccess || windowAccess;
    }
    final target = _reviewTarget();
    if (target == null) {
      return widget.detail.metadata?["disableAdd"] == true;
    }
    final access = context.read<AccessProvider>();
    final hasAccess = access.hasAccess(
      target["productType"] as String,
      itemId: target["productId"] as int?,
    );
    return hasAccess;
  }

  bool _isSubscriptionType(CartItemType type) {
    return type == CartItemType.magazine ||
        type == CartItemType.newspaperSubscription;
  }

  DateTime _normalizeDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime? _parseDate(dynamic rawValue) {
    final raw = rawValue?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;
    final normalized = raw.replaceFirst(" ", "T");
    if (normalized == raw) return null;
    return DateTime.tryParse(normalized);
  }

  bool _hasMagazineWindowAccess({
    required bool hasSubscription,
    required DateTime? start,
    required DateTime? end,
    required DateTime? issueDate,
  }) {
    if (!hasSubscription) return false;

    final normalizedStart = start == null ? null : _normalizeDay(start);
    final normalizedEnd = end == null ? null : _normalizeDay(end);

    // expires_at yoksa sınırsız abonelik kabul edilir.
    if (normalizedEnd == null) {
      if (issueDate == null || normalizedStart == null) return true;
      return !_normalizeDay(issueDate).isBefore(normalizedStart);
    }

    if (issueDate == null) return false;
    final normalizedIssue = _normalizeDay(issueDate);
    if (normalizedStart != null && normalizedIssue.isBefore(normalizedStart)) {
      return false;
    }
    if (normalizedIssue.isAfter(normalizedEnd)) {
      return false;
    }
    return true;
  }

  bool _hasMagazineSubscriptionForIssue(BuildContext context) {
    if (widget.detail.type != CartItemType.magazineIssue) return false;
    final access = context.read<AccessProvider>();
    final magazineIdRaw = widget.detail.metadata?["magazineId"];
    final magazineId = int.tryParse(magazineIdRaw?.toString() ?? "");
    if (magazineId == null) return false;
    return access.hasAccess("magazine", itemId: magazineId);
  }

  bool _hasDirectMagazineIssueAccess(BuildContext context) {
    if (widget.detail.type != CartItemType.magazineIssue) return false;
    final issueIdRaw = widget.detail.metadata?["productId"];
    final issueId = int.tryParse(issueIdRaw?.toString() ?? "");
    if (issueId == null) return false;
    return context.read<AccessProvider>().hasAccessExact(
      "magazine_issue",
      itemId: issueId,
    );
  }

  bool _hasMagazineIssueSubscriptionWindowAccess(BuildContext context) {
    if (widget.detail.type != CartItemType.magazineIssue) return false;
    final access = context.read<AccessProvider>();
    final magazineIdRaw = widget.detail.metadata?["magazineId"];
    final magazineId = int.tryParse(magazineIdRaw?.toString() ?? "");
    final hasSubscription = magazineId != null
        ? access.hasAccess("magazine", itemId: magazineId)
        : false;
    final start = magazineId != null
        ? access.startDate("magazine", itemId: magazineId)
        : null;
    final end = magazineId != null
        ? access.expiry("magazine", itemId: magazineId)
        : null;
    final issueDate = _parseDate(widget.detail.metadata?["issueDate"]);
    final windowAccess = _hasMagazineWindowAccess(
      hasSubscription: hasSubscription,
      start: start,
      end: end,
      issueDate: issueDate,
    );
    // Ürün beklentisi: dergi aboneliği aktifse sayı detayında erişim ver.
    return hasSubscription || windowAccess;
  }

  bool _canReviewWithAccess({
    required AccessProvider access,
    RevenueCatService? revenueCat,
  }) {
    final target = _reviewTarget();
    if (target == null) return false;

    if (widget.detail.forceAccess) return true;

    switch (widget.detail.type) {
      case CartItemType.magazineIssue:
        return _hasDirectMagazineIssueAccess(context) ||
            _hasMagazineIssueSubscriptionWindowAccess(context);
      case CartItemType.newspaperSubscription:
        final rc = revenueCat ?? context.read<RevenueCatService>();
        return access.hasAccess("newspaper_subscription") ||
            rc.isYeniasyaProActive;
      default:
        return access.hasAccess(
          target["productType"] as String,
          itemId: target["productId"] as int?,
        );
    }
  }

  String _magazineIssueViewLabel(BuildContext context) {
    if (widget.detail.type != CartItemType.magazineIssue) {
      return "Dergiyi Görüntüle";
    }
    if (_hasDirectMagazineIssueAccess(context)) {
      return "Görüntüle (Sınırsız Erişim)";
    }
    if (_hasMagazineIssueSubscriptionWindowAccess(context)) {
      return "Görüntüle (Abonelik)";
    }
    return "Dergiyi Görüntüle";
  }

  CartItem? _directCartItem() {
    if (widget.detail.type != CartItemType.book &&
        widget.detail.type != CartItemType.magazineIssue &&
        widget.detail.type != CartItemType.supplement) {
      return null;
    }
    return CartItem(
      id: widget.detail.id,
      title: widget.detail.title,
      subtitle: widget.detail.subtitle,
      imageUrl: widget.detail.imageUrl,
      price: widget.detail.price,
      quantity: 1,
      type: widget.detail.type,
      metadata: widget.detail.metadata,
    );
  }

  String _shareText() {
    final subtitle = widget.detail.subtitle ?? "";
    final shareUrl = widget.detail.metadata?["shareUrl"]?.toString();
    final imageUrl = widget.detail.imageUrl;
    final deepLink = _shareLink();
    final targetUrl = <String>[
      deepLink,
      if (shareUrl != null) shareUrl,
      imageUrl,
    ].firstWhere((u) => u.isNotEmpty, orElse: () => "");

    final parts = <String>[
      widget.detail.title,
      if (subtitle.isNotEmpty) subtitle,
      if (targetUrl.isNotEmpty) targetUrl,
    ];
    return parts.join(" - ");
  }

  String _shareLink() {
    final target = _reviewTarget();
    if (target == null) return "";
    final type = (target["productType"] ?? "").toString();
    final id = target["productId"];
    if (id == null) return "";

    String typeParam;
    switch (type) {
      case "book":
        typeParam = "book";
        break;
      case "magazine":
        typeParam = "magazine";
        break;
      case "magazine_issue":
        typeParam = "magazine_issue";
        break;
      case "newspaper_subscription":
        typeParam = "newspaper_subscription";
        break;
      default:
        typeParam = type;
    }

    const base = "https://yeniasyadijital.com";
    return "$base/urun?type=$typeParam&id=$id";
  }

  Future<void> _openPdfExternal(String url) async {
    final normalized = UploadService.normalizeUrl(url);
    final uri = Uri.parse(normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("PDF açılamadı.")));
    }
  }

  Future<void> _shareGeneral() async {
    final text = _shareText();
    try {
      await Share.share(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Paylaşım başlatılamadı.")));
    }
  }

  Future<void> _shareWhatsApp() async {
    final text = _shareText();
    final uri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}");
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Paylaşım başlatılamadı.")));
    }
  }

  Future<void> _checkLocalCopy() async {
    final fileUrl = _currentFileUrl();
    if (fileUrl == null || fileUrl.isEmpty) {
      if (mounted) setState(() => _hasLocalCopy = false);
      return;
    }
    final cached = await SecureFileService.instance.hasCached(fileUrl);
    if (mounted) setState(() => _hasLocalCopy = cached);
  }

  Future<void> _openPdf(BuildContext context, String fileUrl) async {
    setState(() => _downloadBusy = true);
    try {
      final showPercent =
          !kIsWeb && !(await SecureFileService.instance.hasCached(fileUrl));
      if (showPercent && mounted) setState(() => _downloadProgress = 0);
      await PdfOpenHelper.downloadAndOpen(
        context,
        url: fileUrl,
        title: widget.detail.title,
        isPrivate: true,
        onProgress: showPercent
            ? (p) {
                if (!mounted) return;
                setState(() => _downloadProgress = p);
              }
            : null,
      );
      if (!kIsWeb && mounted) {
        setState(() => _hasLocalCopy = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Dosya açılamadı: ${ErrorManager.parseGraphQLError(e.toString())}",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadBusy = false;
          _downloadProgress = null;
        });
      }
    }
  }

  String? _currentFileUrl() {
    for (final candidate in [
      _resolvedFileUrl,
      widget.detail.metadata?["fileUrl"]?.toString(),
    ]) {
      if (candidate != null && candidate.isNotEmpty) {
        return UploadService.normalizeUrl(candidate);
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int? _newspaperId() {
    final metadataId = _parseInt(widget.detail.metadata?["newspaperId"]);
    if (metadataId != null) return metadataId;
    if (!widget.detail.id.startsWith("news-")) return null;
    return int.tryParse(widget.detail.id.substring(5));
  }

  Future<String?> _fetchProtectedFileUrl() async {
    switch (widget.detail.type) {
      case CartItemType.book:
        final productId = _parseInt(widget.detail.metadata?["productId"]);
        if (productId == null) return null;
        final book = await _bookService.getBookById(productId);
        return book?["book_url"]?.toString();
      case CartItemType.magazineIssue:
        final issueId = _parseInt(widget.detail.metadata?["productId"]);
        if (issueId == null) return null;
        final issue = await _magazineService.getIssueById(issueId);
        return issue?["file_url"]?.toString();
      case CartItemType.newspaperSubscription:
        final newspaperId = _newspaperId();
        if (newspaperId == null) return null;
        final newspaper = await _newspaperService.getById(newspaperId);
        return newspaper?["file_url"]?.toString();
      case CartItemType.magazine:
      case CartItemType.supplement:
        return null;
    }
  }

  Future<String?> _ensureFileUrl() async {
    final current = _currentFileUrl();
    if (current != null && current.isNotEmpty) return current;

    try {
      final fetched = await _fetchProtectedFileUrl();
      if (fetched == null || fetched.isEmpty) return null;
      final normalized = UploadService.normalizeUrl(fetched);
      if (!mounted) return normalized;
      setState(() => _resolvedFileUrl = normalized);
      await _checkLocalCopy();
      return normalized;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "İçerik bağlantısı alınamadı: ${ErrorManager.parseGraphQLError(e.toString())}",
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _openAccessibleContent(
    BuildContext context, {
    int? magazineId,
  }) async {
    if (_openingBook) return;
    setState(() => _openingBook = true);
    try {
      if (widget.detail.type == CartItemType.magazine && magazineId != null) {
        _openMagazineIssues(context, magazineId);
        return;
      }
      final fileUrl = await _ensureFileUrl();
      if (!mounted) return;
      if (fileUrl == null || fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bu içerik için indirme bağlantısı bulunamadı."),
          ),
        );
        return;
      }
      await _openPdf(context, fileUrl);
    } finally {
      if (mounted) setState(() => _openingBook = false);
    }
  }

  Map<String, dynamic>? _reviewTarget() {
    final idRaw = widget.detail.metadata?["productId"];
    final parsedId = int.tryParse(idRaw?.toString() ?? "");
    if (parsedId == null) return null;

    String type;
    switch (widget.detail.type) {
      case CartItemType.book:
        type = "book";
        break;
      case CartItemType.magazine:
        type = "magazine";
        break;
      case CartItemType.magazineIssue:
        type = "magazine_issue";
        break;
      case CartItemType.newspaperSubscription:
        type = "newspaper_subscription";
        break;
      case CartItemType.supplement:
        type = "ek";
        break;
    }

    return {"productId": parsedId, "productType": type};
  }

  Future<void> _loadReviews() async {
    final target = _reviewTarget();
    if (target == null) return;

    setState(() => _reviewsLoading = true);
    try {
      final data = await _reviewService.getReviews(
        productType: target["productType"] as String,
        productId: target["productId"] as int,
      );
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data["reviews"] ?? []);
        _avgRating = (data["average"] as double?) ?? 0;
        _reviewCount = data["count"] is int
            ? data["count"] as int
            : int.tryParse(data["count"]?.toString() ?? "0") ?? 0;
      });
    } catch (_) {
      // Sessiz geç
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _submitReview() async {
    final target = _reviewTarget();
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu ürün için yorum aktif değil.")),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    final userId = user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yorum yapmak için giriş yapın.")),
      );
      return;
    }

    final access = context.read<AccessProvider>();
    final hasAccess = _canReviewWithAccess(access: access);
    if (!hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Satın aldığınız veya aboneliğinizin kapsadığı ürünlere yorum ekleyebilirsiniz.",
          ),
        ),
      );
      return;
    }

    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lütfen yorum yazın.")));
      return;
    }
    if (comment.length > _reviewCommentMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorum en fazla 1.000 karakter olabilir."),
        ),
      );
      return;
    }

    setState(() => _reviewSubmitting = true);
    try {
      await _reviewService.addReview(
        productType: target["productType"] as String,
        productId: target["productId"] as int,
        userId: userId,
        rating: _rating,
        comment: comment,
        userName: user?.name,
        userEmail: user?.email,
        productTitle: widget.detail.title,
      );
      _commentCtrl.clear();
      setState(() => _rating = 5);
      await _loadReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yorumunuz onaya gönderildi.")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Yorum eklenemedi")));
    } finally {
      if (mounted) setState(() => _reviewSubmitting = false);
    }
  }

  Widget _reviewsSection() {
    final target = _reviewTarget();
    if (target == null) {
      return const SizedBox.shrink();
    }
    final access = context.watch<AccessProvider>();
    final revenueCat = context.watch<RevenueCatService>();
    final canReview = _canReviewWithAccess(
      access: access,
      revenueCat: revenueCat,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Değerlendirmeler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            if (_reviewCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "⭐ ${_avgRating.toStringAsFixed(1)} ($_reviewCount)",
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _reviewForm(canReview),
        const SizedBox(height: 12),
        _reviewsLoading
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
            ? const Text("Henüz yorum yok.")
            : Column(
                children: _reviews
                    .map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (r["user_name"] ??
                                          r["user_email"] ??
                                          "Kullanıcı #${r["user_id"] ?? "-"}")
                                      .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ratingStars(
                                (r["rating"] ?? 0) as int? ?? 0,
                                size: 16,
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(r["comment"] ?? "-"),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(r["created_at"]),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }

  Widget _reviewForm(bool canReview) {
    final user = context.watch<AuthProvider>().user;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Puanınız:",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              _ratingStars(_rating, onTap: (v) => setState(() => _rating = v)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: _reviewCommentMaxLength,
            decoration: InputDecoration(
              hintText: user == null
                  ? "Yorum yapmak için giriş yapın"
                  : (canReview
                        ? "Yorumunuzu yazın"
                        : "Sadece satın aldığınız veya aboneliğinizin kapsadığı ürünlere yorum yapılabilir"),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            readOnly: user == null || !canReview,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 140,
              height: 42,
              child: ElevatedButton(
                onPressed: user == null || _reviewSubmitting || !canReview
                    ? null
                    : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _reviewSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Gönder"),
              ),
            ),
          ),
          if (user != null && !canReview)
            const Padding(
              padding: EdgeInsets.only(top: 6.0),
              child: Text(
                "Bu ürünü satın aldıktan veya erişim sağlayan aboneliğiniz aktif olduktan sonra yorum yapabilirsiniz.",
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ratingStars(int value, {double size = 20, ValueChanged<int>? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        return IconButton(
          icon: Icon(
            idx <= value ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: onTap == null ? null : () => onTap(idx),
        );
      }),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  String _formatTurkishDate(String raw) {
    if (raw.isEmpty) return "-";
    DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    final turkishWeekdays = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final turkishMonths = [
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

    final weekday = turkishWeekdays[dt.weekday - 1];
    return "$weekday, ${dt.day} ${turkishMonths[dt.month - 1]} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isWeb ? 120.0 : 16.0;
    final magazineId = widget.detail.type == CartItemType.magazine
        ? int.tryParse(widget.detail.metadata?["productId"]?.toString() ?? "")
        : null;
    final cart = context.watch<CartProvider>();
    final directItem = _directCartItem();
    final hasNewspaperInCart = cart.items.any(
      (item) => item.type == CartItemType.newspaperSubscription,
    );
    final alreadyInCart = directItem != null
        ? cart.contains(directItem)
        : (widget.detail.type == CartItemType.newspaperSubscription &&
              hasNewspaperInCart);

    if (widget.detail.type == CartItemType.newspaperSubscription) {
      final newsTitle = "Yeni Asya Gazetesi";
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          title: Text(
            newsTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _image(widget.detail.imageUrl),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        newsTitle,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if ((widget.detail.subtitle ?? "").isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _formatTurkishDate(widget.detail.subtitle!),
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _buildPrimaryActionButton(
                          context,
                          alreadyInCart,
                          magazineId,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 1,
        title: Text(
          widget.detail.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = isWeb ? 420.0 : 360.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWeb ? 420 : double.infinity,
                        maxHeight: maxHeight,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _image(widget.detail.imageUrl),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (widget.detail.type == CartItemType.book)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.detail.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(Icons.headphones, color: Colors.grey.shade500),
                      label: Text(
                        "Sesli Kitap",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  widget.detail.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if ((widget.detail.subtitle ?? "").isNotEmpty) ...[
                const SizedBox(height: 6),
                if (widget.detail.type == CartItemType.book) ...[
                  const Text(
                    "Yazar",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  widget.detail.subtitle!,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
              if (widget.detail.type != CartItemType.newspaperSubscription) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareGeneral,
                        icon: const Icon(Icons.share),
                        label: const Text("Paylaş"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareWhatsApp,
                        icon: const Icon(
                          FontAwesomeIcons.whatsapp,
                          color: Colors.green,
                        ),
                        label: const Text("WhatsApp"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                widget.detail.description.isNotEmpty
                    ? widget.detail.description
                    : "Açıklama yakında.",
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              if (widget.detail.type != CartItemType.newspaperSubscription)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fiyat",
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                      _priceDisplay(),
                    ],
                  ),
                ),
              if (widget.detail.type == CartItemType.magazine &&
                  magazineId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMagazineIssues(context, magazineId),
                    icon: const Icon(Icons.menu_book),
                    label: const Text("Dergi Sayıları"),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _reviewsSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16,
        ),
        child: widget.detail.type == CartItemType.magazineIssue
            ? Builder(
                builder: (context) {
                  final hasContentAccess = _hasContentAccess(context);
                  final hasMagazineSubscription =
                      _hasMagazineSubscriptionForIssue(context);
                  final hasDirectIssueAccess = _hasDirectMagazineIssueAccess(
                    context,
                  );
                  final issueViewLabel = _magazineIssueViewLabel(context);
                  return Row(
                    children: [
                      if (hasContentAccess)
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _openingBook
                                  ? null
                                  : () {
                                      _openAccessibleContent(context);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(issueViewLabel),
                                  if (_openingBook) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (hasMagazineSubscription && !hasDirectIssueAccess) ...[
                        if (hasContentAccess) const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: alreadyInCart
                                  ? null
                                  : () => _addToCart(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                alreadyInCart
                                    ? "Sepette"
                                    : "Sepete Ekle (Sınırsız Erişim)",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ] else if (!hasContentAccess)
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: alreadyInCart
                                  ? null
                                  : () => _addToCart(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                alreadyInCart
                                    ? "Sepette"
                                    : "Sepete Ekle (Sınırsız Erişim)",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              )
            : SizedBox(
                height: 54,
                child: _buildPrimaryActionButton(
                  context,
                  alreadyInCart,
                  magazineId,
                ),
              ),
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    BuildContext context,
    bool alreadyInCart,
    int? magazineId,
  ) {
    return ElevatedButton(
      onPressed: (alreadyInCart && !_hasContentAccess(context))
          ? null
          : () {
              final hasAccess = _hasContentAccess(context);

              if (hasAccess) {
                _openAccessibleContent(context, magazineId: magazineId);
                return;
              }
              if (widget.detail.type == CartItemType.newspaperSubscription) {
                _openNewspaperPaywall(context);
                return;
              }
              if (widget.detail.type == CartItemType.magazine &&
                  magazineId != null) {
                _selectMagazineSubscriptionType(context, magazineId);
                return;
              }
              _addToCart(context);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _hasContentAccess(context) ? Colors.blue : Colors.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Builder(
        builder: (context) {
          final hasAccess = _hasContentAccess(context);
          final label = (alreadyInCart && !hasAccess)
              ? "Sepette"
              : (hasAccess && widget.detail.type == CartItemType.book)
              ? "Kitabı Görüntüle"
              : _buttonLabel(widget.detail, hasAccess);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasAccess && _openingBook) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                if (_downloadProgress != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    "${(_downloadProgress! * 100).round()}%",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _image(String? url) {
    final isNewspaper =
        widget.detail.type == CartItemType.newspaperSubscription;
    final imageFit = isNewspaper ? BoxFit.contain : BoxFit.cover;
    final imageBackground = isNewspaper
        ? const Color(0xFFF8F8F8)
        : const Color(0xFFE0E0E0);

    if (url == null || url.isEmpty) {
      return Container(
        color: imageBackground,
        child: const Icon(
          Icons.image_not_supported,
          size: 40,
          color: Colors.black54,
        ),
      );
    }

    final fallback = Container(
      color: imageBackground,
      child: const Icon(Icons.broken_image, size: 40, color: Colors.black54),
    );

    final normalized = UploadService.normalizeUrl(url);
    final isData = normalized.startsWith("data:image");

    if (isData) {
      return ColoredBox(
        color: imageBackground,
        child: Padding(
          padding: EdgeInsets.all(isNewspaper ? 8 : 0),
          child: Image.memory(
            base64Decode(normalized.split(",").last),
            fit: imageFit,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    }

    return ColoredBox(
      color: imageBackground,
      child: Padding(
        padding: EdgeInsets.all(isNewspaper ? 8 : 0),
        child: safeImage(
          normalized,
          fit: imageFit,
          fallbackIcon: Icons.broken_image,
        ),
      ),
    );
  }

  String _buttonLabel(ProductDetail detail, bool hasAccess) {
    if (hasAccess) {
      if (detail.forceAccess &&
          (detail.type == CartItemType.magazine ||
              detail.type == CartItemType.magazineIssue ||
              detail.type == CartItemType.newspaperSubscription)) {
        if (detail.type == CartItemType.magazine) return "Oku";
        return "Görüntüle";
      }
      switch (detail.type) {
        case CartItemType.book:
          return "Kitap erişimi aktif";
        case CartItemType.magazine:
          return "Oku";
        case CartItemType.magazineIssue:
          return _magazineIssueViewLabel(context);
        case CartItemType.newspaperSubscription:
          return _accessText(detail, fallback: "Görüntüle");
        case CartItemType.supplement:
          return "Ek erişimi aktif";
      }
    }
    if (!hasAccess && detail.type == CartItemType.newspaperSubscription) {
      return "Abone Ol";
    }
    if (detail.type == CartItemType.magazine) {
      final period = _periodLabel(detail.metadata?["period"]);
      return period == null ? "Abone Ol" : "Abone Ol ($period)";
    }
    return detail.actionLabel;
  }

  String _accessText(ProductDetail detail, {required String fallback}) {
    final target = _reviewTarget();
    if (target == null) return fallback;
    final access = context.read<AccessProvider>();
    final exp = access.expiry(
      target["productType"] as String,
      itemId: target["productId"] as int?,
    );
    if (exp == null) return fallback;
    String two(int v) => v.toString().padLeft(2, '0');
    final dateText = "${two(exp.day)}.${two(exp.month)}.${exp.year}";
    return "$fallback (Bitiş: $dateText)";
  }

  Widget _priceDisplay() {
    if (widget.detail.type != CartItemType.magazine) {
      return Text(
        widget.detail.priceText,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.red,
        ),
      );
    }
    if (widget.detail.forceAccess) {
      return const Text(
        "Ücretsiz",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.red,
        ),
      );
    }
    return const Text(
      "Abonelik seçeneklerinde gösterilir",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.red,
      ),
    );
  }

  String? _periodLabel(dynamic period) {
    final normalized = _normalizePeriod(period);
    switch (normalized) {
      case "1m":
        return "Aylık";
      case "3m":
        return "3 Aylık";
      case "6m":
        return "6 Aylık";
      case "12m":
        return "12 Aylık";
      default:
        return null;
    }
  }

  String? _normalizePeriod(dynamic period) {
    final normalized = period?.toString().toLowerCase();
    return normalized;
  }

  void _openMagazineIssues(BuildContext context, int magazineId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MagazineIssuesScreen(
          magazineId: magazineId,
          magazineTitle: widget.detail.title,
          magazineCoverUrl: widget.detail.imageUrl,
        ),
      ),
    );
  }
}
