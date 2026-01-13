import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cart/cart_provider.dart';
import '../../models/cart_item.dart';
import '../checkout/checkout_screen.dart';
import '../../utils/safe_image.dart';
import '../../services/upload_service.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/promo_code_service.dart';
import '../../services/error/error_manager.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _promoCtrl = TextEditingController();
  final PromoCodeService _promoService = PromoCodeService();
  bool _applyingPromo = false;
  String? _promoMessage;

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyPromo(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir kod girin.")));
      return;
    }

    setState(() {
      _applyingPromo = true;
      _promoMessage = null;
    });

    try {
      final promo = await _promoService.validateAndGet(code);
      if (promo == null) {
        cart.clearPromo();
        setState(() => _promoMessage = "Kod bulunamadı veya geçersiz.");
        return;
      }
      cart.applyPromo(promo);
      setState(() => _promoMessage = "${promo.code} kodu uygulandı (%${promo.discountPercent.toStringAsFixed(0)}).");
    } catch (e) {
      cart.clearPromo();
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      setState(() => _promoMessage = parsed);
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

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
              child: _checkoutSummary(context, cart),
            ),
    );
  }

  Widget _cartItem({
    required CartItem item,
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
                const Text(
                  "Adet: 1",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₺${item.price.toStringAsFixed(2)}",
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

  Widget _promoCodeSection(CartProvider cart) {
    final applied = cart.appliedPromo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: TextField(
                  controller: _promoCtrl,
                  enabled: !_applyingPromo,
                  decoration: const InputDecoration(
                    hintText: "Promosyon kodu girin",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (applied != null)
                TextButton(
                  onPressed: _applyingPromo
                      ? null
                      : () {
                          cart.clearPromo();
                          setState(() => _promoMessage = "Kod kaldırıldı.");
                        },
                  child: const Text(
                    "Kaldır",
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                )
              else
                TextButton(
                  onPressed: _applyingPromo ? null : () => _applyPromo(context),
                  child: _applyingPromo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          "Uygula",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                ),
            ],
          ),
          if (applied != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Chip(
                    label: Text("${applied.code}  -  %${applied.discountPercent.toStringAsFixed(0)} indirim"),
                    backgroundColor: const Color(0xFFE8F5E9),
                  ),
                ],
              ),
            ),
          if (_promoMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                _promoMessage!,
                style: TextStyle(color: _promoMessage!.toLowerCase().contains("uygulandı") ? Colors.green : Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checkoutSummary(BuildContext context, CartProvider cart) {
    final auth = context.read<AuthProvider>();
    final total = cart.totalPrice;
    final discount = cart.discountAmount;
    final payable = cart.totalAfterDiscount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _promoCodeSection(cart),
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
                    "Ara Toplam",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "₺${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("İndirim", style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    discount > 0 ? "-₺${discount.toStringAsFixed(2)}" : "₺0.00",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Ödenecek",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    "₺${payable.toStringAsFixed(2)}",
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
      case CartItemType.supplement:
        return "Ek";
    }
  }
}
