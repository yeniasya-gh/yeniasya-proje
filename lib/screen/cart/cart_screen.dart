import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cart/cart_provider.dart';
import '../../models/cart_item.dart';
import '../checkout/checkout_screen.dart';
import '../../utils/safe_image.dart';
import '../../services/upload_service.dart';
import '../../services/auth/auth_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isWeb = MediaQuery.of(context).size.width > 900;
    final horizontalPadding = isWeb ? 80.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "Sepetim",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: cart.items.isEmpty
          ? const Center(child: Text("Sepetiniz boş"))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ).copyWith(bottom: 120),
                child: Column(
                  children: [
                    ...cart.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _cartItem(
                            item: item,
                            onQtyChange: (q) => cart.updateQuantity(item.id, q),
                            onRemove: () => cart.remove(item.id),
                          ),
                        )),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : SafeArea(
              minimum: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12,
              ),
              child: _checkoutSummary(context, cart.totalPrice),
            ),
    );
  }

  Widget _cartItem({
    required CartItem item,
    required ValueChanged<int> onQtyChange,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _image(item.imageUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle ?? _typeLabel(item.type),
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _qtyButton(Icons.remove, () => onQtyChange(item.quantity - 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        item.quantity.toString(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    _qtyButton(Icons.add, () => onQtyChange(item.quantity + 1)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₺${(item.price * item.quantity).toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: onRemove,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onTap,
      ),
    );
  }

  Widget _promoCodeSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEC),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer, color: Colors.red),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Promosyon kodu girin",
                border: InputBorder.none,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "Uygula",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }

  Widget _checkoutSummary(BuildContext context, double total) {
    final auth = context.read<AuthProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _promoCodeSection(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Toplam Tutar",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "₺${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (!auth.isLoggedIn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ödemeye devam etmek için giriş yapmalısınız.")),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Ödemeye Geç  →",
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _image(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 70,
        height: 90,
        color: const Color(0xFFE0E0E0),
        child: const Icon(Icons.image_not_supported),
      );
    }

    final fallback = Container(
      width: 70,
      height: 90,
      color: const Color(0xFFE0E0E0),
      child: const Icon(Icons.broken_image),
    );

    final normalized = UploadService.normalizeUrl(url);
    final isNetwork =
        normalized.startsWith("http://") || normalized.startsWith("https://");
    final isData = normalized.startsWith("data:image");

    return isData
        ? Image.memory(
            base64Decode(normalized.split(",").last),
            width: 70,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : safeImage(
            normalized,
            width: 70,
            height: 90,
            fit: BoxFit.cover,
            fallbackIcon: Icons.broken_image,
          );
  }

  String _typeLabel(CartItemType type) {
    switch (type) {
      case CartItemType.book:
        return "Kitap";
      case CartItemType.magazine:
        return "Dergi";
      case CartItemType.magazineIssue:
        return "Dergi Sayısı";
      case CartItemType.newspaperSubscription:
        return "Gazete Aboneliği";
    }
  }
}
