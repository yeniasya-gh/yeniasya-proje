import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/order_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/cart/cart_provider.dart';
import '../../services/access_provider.dart';
import '../../models/cart_item.dart';
import '../checkout/order_success_screen.dart';
import '../../services/user_content_access_service.dart';
import '../../services/mail_manager.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/promo_code_service.dart';

class PaymentScreen extends StatefulWidget {
  final int deliveryAddressId;
  final int billingAddressId;
  final String userId;

  const PaymentScreen({
    super.key,
    required this.deliveryAddressId,
    required this.billingAddressId,
    required this.userId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  bool _loading = false;
  final _orderService = OrderService();
  final _accessService = UserContentAccessService();
  final _promoService = PromoCodeService();

  @override
  void dispose() {
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = context.read<CartProvider>();
    final payableTotal = cart.totalAfterDiscount;
    final promo = cart.appliedPromo;
    final discountAmount = cart.discountAmount;
    setState(() => _loading = true);
    try {
      final itemsPayload = cart.items.map((item) {
        final rawProductId = item.metadata?["productId"];
        final parsedProductId = int.tryParse(rawProductId?.toString() ?? "");
        final orderType = _orderProductType(item.type);
        return {
          "product_type": orderType,
          "product_id": parsedProductId ?? 0,
          "title": item.title,
          "unit_price": item.price,
          "quantity": item.quantity,
          "line_total": item.price * item.quantity,
          "metadata": item.metadata,
        };
      }).toList();

      // Access entries to insert before order creation
      final accessItems = <Map<String, dynamic>>[];
      for (final item in cart.items) {
        final rawProductId = item.metadata?["productId"];
        final parsedProductId = int.tryParse(rawProductId?.toString() ?? "");
        String? itemType;
        int? itemId;
        DateTime? expiresAt;

        switch (item.type) {
          case CartItemType.book:
            itemType = "book";
            itemId = parsedProductId;
            break;
          case CartItemType.magazine:
            itemType = "magazine";
            itemId = parsedProductId;
            expiresAt = _computeExpiry(item.metadata?["period"]);
            break;
          case CartItemType.magazineIssue:
            itemType = "magazine_issue";
            itemId = parsedProductId;
            break;
          case CartItemType.newspaperSubscription:
            itemType = "newspaper_subscription";
            itemId = null;
            expiresAt = _computeExpiry(item.metadata?["period"]);
            break;
          case CartItemType.supplement:
            itemType = "ek";
            itemId = parsedProductId;
            break;
        }

        if (itemType == null) continue;

        final qty = item.quantity <= 0 ? 1 : item.quantity;
        for (var i = 0; i < qty; i++) {
          accessItems.add({
            "item_type": itemType,
            "item_id": itemId,
            "started_at": DateTime.now().toIso8601String(),
            "expires_at": expiresAt?.toIso8601String(),
            "purchase_price": item.price,
          });
        }
      }

      if (accessItems.isNotEmpty) {
        await _accessService.grantAccess(
          userId: widget.userId,
          items: accessItems,
        );
      }

      final order = await _orderService.createOrder(
        userId: widget.userId,
        deliveryAddressId: widget.deliveryAddressId,
        billingAddressId: widget.billingAddressId,
        totalPaid: payableTotal,
        promoCodeId: promo?.id,
        promoCode: promo?.code,
        promoDiscountPercent: promo?.discountPercent,
        promoDiscountAmount: discountAmount,
        items: itemsPayload,
      );

      if (promo != null) {
        await _promoService.markUsed(promo.id);
      }

      // Sipariş e-postası
      try {
        final user = context.read<AuthProvider>().user;
        if (user != null) {
          await MailManager.instance.sendOrderSummary(
            to: user.email,
            name: user.name,
            orderId: (order["id"] ?? "").toString(),
            total: payableTotal,
            items: itemsPayload,
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print("🔴 [Mail] Sipariş maili gönderilemedi: $e");
      }

      // refresh access cache
      if (mounted) {
        final access = context.read<AccessProvider>();
        final uid = int.tryParse(widget.userId);
        if (uid != null) {
          await access.load(uid);
        }
      }

      cart.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: order["id"]?.toString() ?? "-",
            total: order["total_paid"]?.toString() ?? payableTotal.toStringAsFixed(2),
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kart ile Öde", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderSummary(cart),
              const SizedBox(height: 16),
              _cardForm(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Ödeme Yap"),
          ),
        ),
      ),
    );
  }

  Widget _orderSummary(CartProvider cart) {
    final items = cart.items;
    final total = cart.totalPrice;
    final discount = cart.discountAmount;
    final payable = cart.totalAfterDiscount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sipariş Özeti", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(child: Text("${i.title} x${i.quantity}")),
                  Text("₺${(i.price * i.quantity).toStringAsFixed(2)}"),
                ],
              ),
            ),
          ),
          if (cart.appliedPromo != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Promosyon (${cart.appliedPromo!.code})", style: const TextStyle(color: Colors.black87)),
                Text("%${cart.appliedPromo!.discountPercent.toStringAsFixed(0)}"),
              ],
            ),
          ],
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Ara Toplam", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("₺${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("İndirim"),
              Text(
                discount > 0 ? "-₺${discount.toStringAsFixed(2)}" : "₺0.00",
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Ödenecek", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("₺${payable.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kart Bilgileri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardHolderCtrl,
              decoration: const InputDecoration(labelText: "Kart Üzerindeki İsim"),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
            ),
            TextFormField(
              controller: _cardNumberCtrl,
              decoration: const InputDecoration(labelText: "Kart Numarası"),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.replaceAll(' ', '').length < 12) ? "Geçerli kart numarası girin" : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryCtrl,
                    decoration: const InputDecoration(labelText: "SKT (AA/YY)"),
                    validator: (v) => (v == null || v.length < 4) ? "Geçerli tarih girin" : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvCtrl,
                    decoration: const InputDecoration(labelText: "CVV"),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.length < 3) ? "CVV girin" : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _orderProductType(CartItemType type) {
    switch (type) {
      case CartItemType.book:
        return "book";
      case CartItemType.magazine:
        return "magazine";
      case CartItemType.magazineIssue:
        return "magazine_one";
      case CartItemType.newspaperSubscription:
        return "newspaper_subscription";
      case CartItemType.supplement:
        return "ek";
    }
  }

  DateTime? _computeExpiry(dynamic periodRaw) {
    final now = DateTime.now();
    final period = periodRaw?.toString().toLowerCase();
    if (period == "6m" || period == "6ay" || period == "6" || period == "6month") {
      return DateTime(now.year, now.month + 6, now.day);
    }
    if (period == "12m" || period == "12ay" || period == "12" || period == "12month" || period == "1y") {
      return DateTime(now.year + 1, now.month, now.day);
    }
    return null;
  }
}
