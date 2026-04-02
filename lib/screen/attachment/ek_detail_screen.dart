import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../services/access_provider.dart';
import '../../services/cart/cart_provider.dart';
import '../../services/upload_service.dart';
import '../../utils/safe_image.dart';
import '../../utils/cart_feedback.dart';
import '../../utils/ek_normalizer.dart';
import '../profile/pdf_viewer_screen.dart';
import '../../services/auth/auth_provider.dart';

class EkDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ek;

  const EkDetailScreen({super.key, required this.ek});

  @override
  Widget build(BuildContext context) {
    final data = normalizeEk(ek);
    final price = _price(data["fiyat"]);
    final isFree = price == 0;
    final access = context.watch<AccessProvider>();
    final cart = context.watch<CartProvider>();
    final hasAccess = access.hasAccess("ek", itemId: _id(data));

    final imageUrl = UploadService.normalizeUrl(
      data["photo_url"]?.toString() ?? "",
    );
    final item = CartItem(
      id: "ek-${_id(data)}",
      title: data["ad"]?.toString() ?? "Ek",
      subtitle: data["aciklama"]?.toString(),
      imageUrl: data["photo_url"]?.toString() ?? "",
      price: price,
      quantity: 1,
      type: CartItemType.supplement,
      metadata: {
        "productId": _id(data),
        "pdf_url": data["pdf_url"],
        "photo_url": data["photo_url"],
        "title": data["ad"],
        "is_public": data["is_public"],
      },
    );
    final alreadyInCart = cart.contains(item);

    return Scaffold(
      appBar: AppBar(title: const Text("Ek Detayı")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 320,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: safeImage(
                    imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.image_not_supported,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data["ad"]?.toString() ?? "-",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              (data["aciklama"] ?? "").toString().isEmpty
                  ? "Açıklama bulunmuyor."
                  : data["aciklama"].toString(),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip(
                  isFree ? "Ücretsiz" : "Ücretli",
                  isFree ? Colors.green : Colors.red,
                ),
                Text(
                  isFree ? "Ücretsiz" : "₺${price.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (alreadyInCart && !(isFree || hasAccess))
                ? null
                : () {
                    if (isFree || hasAccess) {
                      _openPdf(
                        context,
                        data["pdf_url"]?.toString() ?? "",
                        isFree: isFree,
                      );
                    } else {
                      _addToCart(context, data, price);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: (isFree || hasAccess) ? Colors.blue : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              (isFree || hasAccess)
                  ? "Görüntüle"
                  : (alreadyInCart ? "Sepette" : "Sepete Ekle"),
            ),
          ),
        ),
      ),
    );
  }

  void _openPdf(BuildContext context, String url, {required bool isFree}) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("PDF bulunamadı")));
      return;
    }
    final auth = context.read<AuthProvider>();
    if (isFree && !auth.isLoggedIn) {
      showLoginRequirementDialog(
        context,
        message:
            "Ücretsiz eki görüntülemek için üye girişi yapmanız gerekmektedir.",
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: UploadService.normalizeUrl(url),
          title: normalizeEk(ek)["ad"]?.toString() ?? "Ek",
          // Ücretsiz de olsa private izleme
          isPrivate: true,
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, Map<String, dynamic> ek, double price) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showLoginRequirementDialog(context);
      return;
    }
    final cart = context.read<CartProvider>();
    final id = _id(ek);
    final item = CartItem(
      id: "ek-$id",
      title: ek["ad"]?.toString() ?? "Ek",
      subtitle: ek["aciklama"]?.toString(),
      imageUrl: ek["photo_url"]?.toString() ?? "",
      price: price,
      quantity: 1,
      type: CartItemType.supplement,
      metadata: {
        "productId": id,
        "pdf_url": ek["pdf_url"],
        "photo_url": ek["photo_url"],
        "title": ek["ad"],
        "is_public": ek["is_public"],
      },
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

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  double _price(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? "") ?? 0;
  }

  int? _id(Map<String, dynamic> ek) {
    final id = ek["id"];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? "");
  }
}
