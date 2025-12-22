import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/cart_item.dart';
import '../../services/cart/cart_provider.dart';
import '../../utils/safe_image.dart';
import '../profile/pdf_viewer_screen.dart';
import '../../services/upload_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/access_provider.dart';
import '../../services/review_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/secure_file_service.dart';
import '../../services/error/error_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

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
  });

  String get priceText => price > 0 ? "₺${price.toStringAsFixed(2)}" : "Fiyat bilgisi yakında";
}

class ProductDetailScreen extends StatefulWidget {
  final ProductDetail detail;

  const ProductDetailScreen({super.key, required this.detail});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _selectedIssue;
  final _reviewService = ReviewService();
  final TextEditingController _commentCtrl = TextEditingController();
  int _rating = 5;
  bool _reviewSubmitting = false;
  bool _reviewsLoading = false;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  int _reviewCount = 0;
  bool _hasLocalCopy = false;
  bool _downloadBusy = false;

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
    final cart = context.read<CartProvider>();
    if (_selectedIssue != null) {
      final issue = _selectedIssue!;
      final issueId = issue["id"] as int?;
      final issueNumber = issue["issue_number"]?.toString() ?? "";
      final price = issue["price"] as double? ?? 0;
      cart.addOrIncrement(
        CartItem(
          id: "mag-issue-$issueId",
          title: "${widget.detail.title} - Sayı $issueNumber",
          subtitle: null,
          imageUrl: issue["photo_url"]?.toString() ?? "",
          price: price,
          quantity: 1,
          type: CartItemType.magazineIssue,
          metadata: {
            "productId": issueId,
            "magazineId": issue["magazine_id"],
            "fileUrl": issue["file_url"],
            "photoUrl": issue["photo_url"],
            "issueNumber": issueNumber,
          },
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sayı $issueNumber sepete eklendi")),
      );
      setState(() => _selectedIssue = null);
      return;
    }

    cart.addOrIncrement(
      CartItem(
        id: widget.detail.id,
        title: widget.detail.title,
        subtitle: widget.detail.subtitle,
        imageUrl: widget.detail.imageUrl,
        price: widget.detail.price,
        quantity: 1,
        type: widget.detail.type,
        metadata: widget.detail.metadata,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sepete eklendi")),
    );
  }

  bool _hasContentAccess(BuildContext context) {
    if (_hasLocalCopy) return true;
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

  String _shareText() {
    final subtitle = widget.detail.subtitle ?? "";
    final shareUrl = widget.detail.metadata?["shareUrl"]?.toString();
    final fileUrl = widget.detail.metadata?["fileUrl"]?.toString();
    final imageUrl = widget.detail.imageUrl;
    final deepLink = _shareLink();
    final targetUrl = [
      deepLink,
      shareUrl,
      fileUrl,
      imageUrl,
    ].firstWhere((u) => u != null && u.toString().isNotEmpty, orElse: () => "");

    final parts = <String>[
      widget.detail.title,
      if (subtitle.isNotEmpty) subtitle,
      if (targetUrl is String && targetUrl.isNotEmpty) targetUrl,
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

    const base = "https://yeniasyadigital.com";
    return "$base/urun?type=$typeParam&id=$id";
  }

  Future<void> _openPdfExternal(String url) async {
    final normalized = UploadService.normalizeUrl(url);
    final uri = Uri.parse(normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF açılamadı.")),
      );
    }
  }

  Future<void> _shareGeneral() async {
    final text = _shareText();
    try {
      await Share.share(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paylaşım başlatılamadı.")));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paylaşım başlatılamadı.")));
    }
  }

  Future<void> _checkLocalCopy() async {
    final fileUrl = _currentFileUrl();
    if (fileUrl == null || fileUrl.isEmpty) return;
    final cached = await SecureFileService.instance.hasCached(fileUrl);
    if (mounted) setState(() => _hasLocalCopy = cached);
  }

  Future<void> _openPdf(BuildContext context, String fileUrl) async {
    setState(() => _downloadBusy = true);
    try {
      await SecureFileService.instance.getPdfBytes(url: fileUrl, isPrivate: true);
      setState(() => _hasLocalCopy = true);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: fileUrl,
            title: widget.detail.title,
            isPrivate: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya açılamadı: ${ErrorManager.parseGraphQLError(e.toString())}")),
      );
    } finally {
      if (mounted) setState(() => _downloadBusy = false);
    }
  }

  String? _currentFileUrl() {
    // Öncelik seçili sayı -> onun file_url'i
    final selFile = _selectedIssue?["file_url"]?.toString();
    if (selFile != null && selFile.isNotEmpty) {
      return UploadService.normalizeUrl(selFile);
    }
    // Yoksa ürün metadata fileUrl
    final baseUrl = widget.detail.metadata?["fileUrl"]?.toString();
    if (baseUrl != null && baseUrl.isNotEmpty) {
      return UploadService.normalizeUrl(baseUrl);
    }
    return null;
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

    return {
      "productId": parsedId,
      "productType": type,
    };
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
        _reviewCount = data["count"] is int ? data["count"] as int : int.tryParse(data["count"]?.toString() ?? "0") ?? 0;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu ürün için yorum aktif değil.")));
      return;
    }

    final user = context.read<AuthProvider>().user;
    final userId = user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum yapmak için giriş yapın.")));
      return;
    }

    final access = context.read<AccessProvider>();
    final hasAccess = access.hasAccess(target["productType"] as String, itemId: target["productId"] as int?);
    if (!hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Satın aldığınız ürünlere yorum ekleyebilirsiniz.")));
      return;
    }

    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen yorum yazın.")));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorumunuz onaya gönderildi.")));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum eklenemedi")));
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
    final canReview = access.hasAccess(target["productType"] as String, itemId: target["productId"] as int?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Değerlendirmeler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (_reviewCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text("⭐ ${_avgRating.toStringAsFixed(1)} ($_reviewCount)"),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (access.expiry(target["productType"] as String, itemId: target["productId"] as int?) != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Abonelik bitiş: ${_formatDate(access.expiry(target["productType"] as String, itemId: target["productId"] as int?)!)}",
              style: const TextStyle(color: Colors.black54),
            ),
          ),
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
                                      (r["user_name"] ?? r["user_email"] ?? "Kullanıcı #${r["user_id"] ?? "-"}").toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _ratingStars((r["rating"] ?? 0) as int? ?? 0, size: 16),
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
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
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
              const Text("Puanınız:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              _ratingStars(_rating, onTap: (v) => setState(() => _rating = v)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: user == null
                  ? "Yorum yapmak için giriş yapın"
                  : (canReview ? "Yorumunuzu yazın" : "Sadece satın alınan ürünlere yorum yapılabilir"),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
            readOnly: user == null || !canReview,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            height: 42,
            child: ElevatedButton(
              onPressed: user == null || _reviewSubmitting || !canReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: _reviewSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Gönder"),
            ),
          ),
          if (user != null && !canReview)
            const Padding(
              padding: EdgeInsets.only(top: 6.0),
              child: Text(
                "Bu ürünü satın aldıktan sonra yorum yapabilirsiniz.",
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

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isWeb ? 120.0 : 16.0;
    final magazineId = widget.detail.type == CartItemType.magazine
        ? int.tryParse(widget.detail.metadata?["productId"]?.toString() ?? "")
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 1,
        title: Text(widget.detail.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_selectedIssue != null) {
              setState(() => _selectedIssue = null);
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
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
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.headphones, color: Colors.grey.shade500),
                        label: Text(
                          "Sesli Kitap",
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  )
                else
                  Text(widget.detail.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if ((widget.detail.subtitle ?? "").isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.detail.subtitle!, style: const TextStyle(color: Colors.black54, fontSize: 14)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareGeneral,
                        icon: const Icon(Icons.share),
                        label: const Text("Sosyal Medyada Paylaş"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareWhatsApp,
                        icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                        label: const Text("WhatsApp"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.detail.description.isNotEmpty ? widget.detail.description : "Açıklama yakında.",
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Fiyat", style: TextStyle(fontSize: 15, color: Colors.black54)),
                      Text(
                        widget.detail.priceText,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.detail.type == CartItemType.magazine && magazineId != null) ...[
                  _MagazineIssuesSection(
                    magazineId: magazineId,
                    magazineTitle: widget.detail.title,
                    selectedIssueId: _selectedIssue?["id"] as int?,
                    onSelect: (issue, price) {
                      setState(() {
                        _selectedIssue = {
                          ...issue,
                          "price": price,
                        };
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 16),
                _reviewsSection(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              final hasAccess = _hasContentAccess(context);

              if (_selectedIssue != null) {
                _addToCart(context);
                return;
              }
              if (hasAccess) {
                final fileUrl = _currentFileUrl();
                if (fileUrl != null && fileUrl.isNotEmpty) {
                  if (kIsWeb) {
                    _openPdfExternal(fileUrl);
                  } else {
                    _openPdf(context, fileUrl);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bu içerik için indirme bağlantısı bulunamadı.")),
                  );
                }
                return;
              }
              _addToCart(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedIssue != null
                  ? Colors.red
                  : (_hasContentAccess(context) ? Colors.blue : Colors.red),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Builder(
              builder: (context) {
                final hasAccess = _hasContentAccess(context);
                final label = _buttonLabel(widget.detail, hasAccess);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFFE0E0E0),
        child: const Icon(Icons.image_not_supported, size: 40, color: Colors.black54),
      );
    }

    final fallback = Container(
      color: const Color(0xFFE0E0E0),
      child: const Icon(Icons.broken_image, size: 40, color: Colors.black54),
    );

    final normalized = UploadService.normalizeUrl(url);
    final isNetwork =
        normalized.startsWith("http://") || normalized.startsWith("https://");
    final isData = normalized.startsWith("data:image");

    if (isData) {
      return Image.memory(
        base64Decode(normalized.split(",").last),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return safeImage(
      normalized,
      fit: BoxFit.cover,
      fallbackIcon: Icons.broken_image,
    );
  }

  String _buttonLabel(ProductDetail detail, bool hasAccess) {
    if (_selectedIssue != null) {
      final price = _selectedIssue?["price"] as double? ?? 0;
      return "Sepete Ekle (₺${price.toStringAsFixed(2)})";
    }

      if (hasAccess) {
        switch (detail.type) {
          case CartItemType.book:
            return "Kitap erişimi aktif";
          case CartItemType.magazine:
            return _accessText(detail, fallback: "Abonelik aktif");
          case CartItemType.magazineIssue:
            return "Dergi sayısı erişimi aktif";
          case CartItemType.newspaperSubscription:
            return _accessText(detail, fallback: "Abonelik aktif");
          case CartItemType.supplement:
            return "Ek erişimi aktif";
        }
      }
    return detail.actionLabel;
  }

  String _accessText(ProductDetail detail, {required String fallback}) {
    final target = _reviewTarget();
    if (target == null) return fallback;
    final access = context.read<AccessProvider>();
    final exp = access.expiry(target["productType"] as String, itemId: target["productId"] as int?);
    if (exp == null) return fallback;
    String two(int v) => v.toString().padLeft(2, '0');
    final dateText = "${two(exp.day)}.${two(exp.month)}.${exp.year}";
    return "$fallback (Bitiş: $dateText)";
  }
}

class _MagazineIssuesSection extends StatelessWidget {
  final int magazineId;
  final String magazineTitle;
  final int? selectedIssueId;
  final void Function(Map<String, dynamic> issue, double price) onSelect;

  const _MagazineIssuesSection({
    required this.magazineId,
    required this.magazineTitle,
    required this.selectedIssueId,
    required this.onSelect,
  });

  double _parsePrice(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? "") ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final service = AdminMagazineService();
    final access = context.watch<AccessProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sayılar",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: service.getIssues(magazineId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            if (snapshot.hasError) {
              return Text("Sayılar yüklenemedi: ${snapshot.error}");
            }
            final issues = snapshot.data ?? [];
            if (issues.isEmpty) {
              return const Text("Henüz sayı eklenmedi.");
            }
            return SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: issues.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final issue = issues[i];
                  final issueId = issue["id"] as int?;
                  final issueNumber = issue["issue_number"]?.toString() ?? "";
                  final imageUrl = issue["photo_url"]?.toString() ?? "";
                  final sale = _parsePrice(issue["campaign_price"] ?? issue["sale_price"]);
                  final hasAccess = access.hasAccess("magazine_issue", itemId: issueId);
                  final isSelected = selectedIssueId != null && selectedIssueId == issueId;

                  return GestureDetector(
                    onTap: hasAccess
                        ? null
                        : () {
                            if (issueId == null) return;
                            onSelect({
                              "id": issueId,
                              "issue_number": issueNumber,
                              "photo_url": imageUrl,
                              "file_url": issue["file_url"],
                              "magazine_id": magazineId,
                            }, sale);
                          },
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                          child: safeImage(
                            UploadService.normalizeUrl(imageUrl),
                            width: 70,
                            height: 95,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.book,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Sayı $issueNumber",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₺${sale.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: hasAccess
                                  ? Colors.grey
                                  : (isSelected ? Colors.red : Colors.black),
                            ),
                          ),
                          if (hasAccess)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                "Sahip",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
