import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../services/error/error_manager.dart';
import '../../utils/order_item_visual.dart';
import '../../utils/purchase_channel_labels.dart';
import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/admin/admin_newspaper_service.dart';
import '../../services/ek_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _orderService = OrderService();
  final _bookService = AdminBookService();
  final _magazineService = AdminMagazineService();
  final _newspaperService = AdminNewspaperService();
  final _ekService = EkService();
  bool _loading = true;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final detail = await _orderService.getOrderDetail(widget.orderId);
      if (!mounted) return;
      final hydrated = await _hydrateOrderDetail(detail);
      if (!mounted) return;
      setState(() => _order = hydrated);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _hydrateOrderDetail(
    Map<String, dynamic>? detail,
  ) async {
    if (detail == null) return null;
    final rawItems = detail["order_items"];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : <Map<String, dynamic>>[];
    if (items.isEmpty) return detail;

    final hydrated = await Future.wait(items.map(_hydrateOrderItem));
    return {...detail, "order_items": hydrated};
  }

  Future<Map<String, dynamic>> _hydrateOrderItem(
    Map<String, dynamic> item,
  ) async {
    if ((orderItemImageUrl(item) ?? "").isNotEmpty) return item;

    final type = _itemType(item);
    final productId = _itemProductId(item);
    if (productId == null) return item;

    String? imageUrl;
    try {
      switch (type) {
        case "book":
          final book = await _bookService.getBookById(productId);
          imageUrl = book?["cover_url"]?.toString();
          break;
        case "magazine":
          final magazine = await _magazineService.getMagazineById(productId);
          imageUrl = magazine?["cover_image_url"]?.toString();
          break;
        case "magazine_issue":
        case "magazine_one":
          final issue = await _magazineService.getIssueById(productId);
          imageUrl =
              issue?["photo_url"]?.toString() ?? issue?["file_url"]?.toString();
          break;
        case "newspaper":
        case "newspaper_subscription":
          final newspaper = await _newspaperService.getById(productId);
          imageUrl =
              newspaper?["image_url"]?.toString() ??
              newspaper?["file_url"]?.toString();
          break;
        case "ek":
          final ek = await _ekService.getEk(productId);
          imageUrl = ek?["photo_url"]?.toString();
          break;
      }
    } catch (_) {
      imageUrl = null;
    }

    final normalized = imageUrl == null ? "" : imageUrl.trim();
    if (normalized.isEmpty) return item;

    return {
      ...item,
      "image_url": normalized,
      "imageUrl": normalized,
      "photo_url": normalized,
      "photoUrl": normalized,
      "cover_url": normalized,
      "coverUrl": normalized,
      "cover_image_url": normalized,
      "coverImageUrl": normalized,
      "thumbnail_url": normalized,
      "thumbnailUrl": normalized,
    };
  }

  String _itemType(Map<String, dynamic> item) {
    return (item["product_type"] ?? item["type"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
  }

  int? _itemProductId(Map<String, dynamic> item) {
    final metadata = item["metadata"] as Map<String, dynamic>? ?? const {};
    final candidates = [
      item["product_id"],
      item["productId"],
      item["ek_id"],
      metadata["product_id"],
      metadata["productId"],
      metadata["item_id"],
      metadata["id"],
      metadata["ek_id"],
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (candidate is int) return candidate;
      if (candidate is num) return candidate.toInt();
      final parsed = int.tryParse(candidate.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        title: Text("Sipariş #${widget.orderId}"),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _order == null
            ? const Center(child: Text("Sipariş bulunamadı."))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _itemsCard(),
                    const SizedBox(height: 12),
                    _summaryCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryCard() {
    final status = _order?["status"]?.toString() ?? "-";
    final total = _order?["total_paid"]?.toString() ?? "0";
    final date = _formatDate(_order?["created_at"]);
    final promoCode = _order?["promo_code"]?.toString();
    final promoDiscountAmount = (_order?["promo_discount_amount"] is num)
        ? (_order?["promo_discount_amount"] as num).toDouble()
        : double.tryParse(
                _order?["promo_discount_amount"]?.toString() ?? "0",
              ) ??
              0;
    final promoPercent = _order?["promo_discount_percent"];
    final paymentChannel = PurchaseChannelLabels.orderChannelLabel(
      Map<String, dynamic>.from(_order ?? <String, dynamic>{}),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Text(
                "Sipariş Özeti",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 8),
          Text(date, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            "Ödeme Kanalı: $paymentChannel",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          if (promoCode != null && promoCode.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Promosyon ($promoCode)",
                  style: const TextStyle(color: Colors.black87),
                ),
                Text(
                  promoPercent == null ? " " : "%${promoPercent.toString()}",
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("İndirim"),
                Text(
                  "-₺${promoDiscountAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(),
          ],
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
    );
  }

  Widget _itemsCard() {
    final rawItems = _order?["order_items"];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ürünler",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...items.map((i) {
            final type = _typeLabel(i["product_type"]);
            final price = (i["line_total"] ?? i["unit_price"] ?? 0).toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 72,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: orderItemThumbnail(i, width: 56, height: 72),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i["title"] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Adet: ${i["quantity"] ?? 1}  |  Tip: $type",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₺$price",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "Ürün bulunamadı.",
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
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
        return status;
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return "-";
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw.toString());
    } catch (_) {}
    if (dt == null) return raw.toString();
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(dt.hour)}:${two(dt.minute)} ${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  String _typeLabel(dynamic raw) {
    final normalized = (raw ?? "").toString().trim().toLowerCase();
    switch (normalized) {
      case "book":
        return "Kitap";
      case "magazine":
      case "magazine_issue":
      case "magazine_one":
        return "Dergi";
      case "supplement":
      case "ek":
        return "Ek";
      case "newspaper":
      case "newspaper_subscription":
        return "Gazete";
      case "book_bundle":
        return "Kitap Paketi";
      default:
        return raw?.toString() ?? "-";
    }
  }
}
