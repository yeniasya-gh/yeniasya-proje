import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_item.dart';
import '../../services/cart/cart_provider.dart';
import '../../utils/safe_image.dart';
import '../profile/pdf_viewer_screen.dart';
import '../../services/upload_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/access_provider.dart';

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
                Text(widget.detail.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if ((widget.detail.subtitle ?? "").isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.detail.subtitle!, style: const TextStyle(color: Colors.black54, fontSize: 14)),
                ],
                const SizedBox(height: 12),
                Text(
                  widget.detail.description.isNotEmpty ? widget.detail.description : "Açıklama yakında.",
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 16),
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
              final disable = widget.detail.metadata?["disableAdd"] == true;
              final fileUrl = widget.detail.metadata?["fileUrl"]?.toString();
              if (_selectedIssue != null) {
                _addToCart(context);
                return;
              }
              if (disable && fileUrl != null && fileUrl.isNotEmpty) {
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
                return;
              }
              if (disable) return;
              _addToCart(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedIssue != null
                  ? Colors.red
                  : (widget.detail.metadata?["disableAdd"] == true ? Colors.blue : Colors.red),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_buttonLabel(widget.detail)),
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

  String _buttonLabel(ProductDetail detail) {
    if (_selectedIssue != null) {
      final price = _selectedIssue?["price"] as double? ?? 0;
      return "Sepete Ekle (₺${price.toStringAsFixed(2)})";
    }

    final disable = detail.metadata?["disableAdd"] == true;
    if (disable) {
      switch (detail.type) {
        case CartItemType.book:
          return "Kitabı Gör";
        case CartItemType.magazine:
          return "Dergiyi Gör";
        case CartItemType.magazineIssue:
          return "Dergi Sayısını Gör";
        case CartItemType.newspaperSubscription:
          return "Gazeteyi Gör";
      }
    }
    return detail.actionLabel;
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
