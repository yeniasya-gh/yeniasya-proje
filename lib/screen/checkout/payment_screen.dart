import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../services/order_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/cart/cart_provider.dart';
import '../../services/access_provider.dart';
import '../../models/cart_item.dart';
import '../../models/app_user.dart';
import '../checkout/order_success_screen.dart';
import '../../services/user_content_access_service.dart';
import '../../services/mail_manager.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/promo_code_service.dart';
import '../../services/address_service.dart';
import '../../services/payment_service.dart';
import 'payment_webview_screen.dart';
import '../../config/payment_config.dart';
import '../../helpers/payment_web_helper.dart';

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
  final _paymentService = PaymentService();
  final _addressService = AddressService();

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
    FocusScope.of(context).unfocus();
    final cart = context.read<CartProvider>();
    final payableTotal = cart.totalAfterDiscount;
    final promo = cart.appliedPromo;
    final discountAmount = cart.discountAmount;
    try {
      setState(() => _loading = true);
      // ignore: avoid_print
      print("🟦 PaymentScreen.submit -> start");
      final user = context.read<AuthProvider>().user;
      if (user == null) {
        throw Exception("Kullanici bilgisi bulunamadi.");
      }
      // ignore: avoid_print
      print("🟦 PaymentScreen.submit -> user: ${user.id}");

      final itemsPayload = _buildOrderItemsPayload(cart.items);
      final accessItems = _buildAccessItems(cart.items);
      // ignore: avoid_print
      print("🟦 PaymentScreen.submit -> items: ${itemsPayload.length}, access: ${accessItems.length}");
      final billing = await _addressService.getAddressById(widget.billingAddressId);
      final delivery = await _addressService.getAddressById(widget.deliveryAddressId);
      final merchantPaymentId = _buildMerchantPaymentId(user.id);
      // ignore: avoid_print
      print("🟦 PaymentScreen.submit -> merchantPaymentId: $merchantPaymentId");

      final sessionPayload = _buildSessionPayload(
        user: user,
        total: payableTotal,
        discountAmount: discountAmount,
        billing: billing,
        delivery: delivery,
        items: cart.items,
        merchantPaymentId: merchantPaymentId,
      );
      final sessionToken = await _paymentService.createSession(payload: sessionPayload);
      // ignore: avoid_print
      print("🟦 PaymentScreen.submit -> sessionToken ok");

      if (!mounted) return;
      final createdOrder = await _orderService.createOrder(
        userId: widget.userId,
        deliveryAddressId: widget.deliveryAddressId,
        billingAddressId: widget.billingAddressId,
        totalPaid: payableTotal,
        status: "pending",
        promoCodeId: promo?.id,
        promoCode: promo?.code,
        promoDiscountPercent: promo?.discountPercent,
        promoDiscountAmount: discountAmount,
        items: itemsPayload,
        merchantPaymentId: merchantPaymentId,
        paymentSessionToken: sessionToken,
        paymentApproved: false,
      );

      final orderId = createdOrder["id"] as int?;
      if (orderId == null) {
        throw Exception("Siparis olusturulamadi.");
      }

      final redirectPayload = PaymentRedirectPayload(
        sessionToken: sessionToken,
        cardPan: _sanitizeCardNumber(_cardNumberCtrl.text),
        cardExpiry: _normalizeExpiry(_expiryCtrl.text),
        cardCvv: _cvvCtrl.text.trim(),
        nameOnCard: _cardHolderCtrl.text.trim(),
      );
      // ignore: avoid_print
      print("🟦 PaymentScreen.submit -> open webview");

      PaymentResult? result;

      if (kIsWeb) {
        // Web: POST to redirect endpoint and open popup for 3D payment
        result = await _handleWebPayment(redirectPayload, orderId);
      } else {
        // iOS/Android: Use WebView screen
        result = await Navigator.push<PaymentResult>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              payload: redirectPayload,
              redirectUri: _paymentService.redirectUri(),
              returnUrl: PaymentConfig.returnUrl,
              orderId: orderId,
            ),
          ),
        );
      }

      if (result == null || !result.success) {
        if (mounted) {
          setState(() => _loading = false);
          final msg = result?.errorMsg ?? result?.message ?? "Odeme tamamlanamadi.";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        // Status enumda desteklenmeyen değer hatasını önlemek için başarısızlığı kayda pending bırakıyoruz.
        await _orderService.updateOrderPaymentStatus(
          orderId: orderId,
          status: "pending",
          paymentApproved: false,
          paymentResponseCode: result?.responseCode,
          paymentResponseMsg: result?.responseMsg,
          paymentErrorCode: result?.errorCode,
          paymentErrorMsg: result?.errorMsg ?? result?.message,
        );
        // ignore: avoid_print
        print("🟨 PaymentScreen.submit -> webview failed: ${result?.message}");
        return;
      }

      // ignore: avoid_print
      print("🟩 PaymentScreen.submit -> webview success");
      await _orderService.updateOrderPaymentStatus(
        orderId: orderId,
        status: "paid",
        paymentApproved: true,
        paymentResponseCode: result.responseCode,
        paymentResponseMsg: result.responseMsg,
        paymentErrorCode: result.errorCode,
        paymentErrorMsg: result.errorMsg,
      );
      await _finalizeOrder(
        orderId: orderId,
        cart: cart,
        payableTotal: payableTotal,
        promoId: promo?.id,
        itemsPayload: itemsPayload,
        accessItems: accessItems,
      );
    } catch (e) {
      // ignore: avoid_print
      print("🟥 PaymentScreen.submit error: $e");
      if (mounted) {
        setState(() => _loading = false);
        if (e is PaymentSessionException) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        } else {
          final parsed = ErrorManager.parseGraphQLError(e.toString());
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
        }
      }
    }
  }

  Future<void> _finalizeOrder({
    required int orderId,
    required CartProvider cart,
    required double payableTotal,
    required List<Map<String, dynamic>> itemsPayload,
    required List<Map<String, dynamic>> accessItems,
    int? promoId,
  }) async {
    setState(() => _loading = true);
    try {
      // ignore: avoid_print
      print("🟦 PaymentScreen.finalize -> start");
      if (accessItems.isNotEmpty) {
        await _accessService.grantAccess(
          userId: widget.userId,
          items: accessItems,
        );
      }
      // ignore: avoid_print
      print("🟦 PaymentScreen.finalize -> access ok");

      if (promoId != null) {
        await _promoService.markUsed(promoId);
      }

      try {
        final user = context.read<AuthProvider>().user;
        if (user != null) {
          await MailManager.instance.sendOrderSummary(
            to: user.email,
            name: user.name,
            orderId: orderId.toString(),
            total: payableTotal,
            items: itemsPayload,
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print("🔴 [Mail] Siparis maili gonderilemedi: $e");
      }

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
            orderId: orderId.toString(),
            total: payableTotal.toStringAsFixed(2),
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      // ignore: avoid_print
      print("🟥 PaymentScreen.finalize error: $e");
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildOrderItemsPayload(List<CartItem> items) {
    return items.map((item) {
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
  }

  List<Map<String, dynamic>> _buildAccessItems(List<CartItem> items) {
    final accessItems = <Map<String, dynamic>>[];
    for (final item in items) {
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
          expiresAt = _computeExpiry(item.metadata?["periodMonths"] ?? item.metadata?["period"]);
          break;
        case CartItemType.magazineIssue:
          itemType = "magazine_issue";
          itemId = parsedProductId;
          break;
        case CartItemType.newspaperSubscription:
          itemType = "newspaper_subscription";
          itemId = parsedProductId == 0 ? null : parsedProductId;
          expiresAt = _computeExpiry(item.metadata?["periodMonths"] ?? item.metadata?["period"]);
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
    return accessItems;
  }

  Map<String, dynamic> _buildSessionPayload({
    required AppUser user,
    required double total,
    required double discountAmount,
    required Map<String, dynamic>? billing,
    required Map<String, dynamic>? delivery,
    required List<CartItem> items,
    required String merchantPaymentId,
  }) {
    final orderItems = items
        .map((item) => {
              "productCode": item.metadata?["productCode"]?.toString() ??
                  item.metadata?["productId"]?.toString() ??
                  item.id,
              "name": item.title,
              "description": item.subtitle ??
                  item.metadata?["description"]?.toString() ??
                  "",
              "quantity": item.quantity,
              "amount": double.parse(item.price.toStringAsFixed(2)),
            })
        .toList();

    final payload = {
      "AMOUNT": total.toStringAsFixed(2),
      "CURRENCY": "TRY",
      "MERCHANTPAYMENTID": merchantPaymentId,
      "RETURNURL": PaymentConfig.returnUrl,
      "CUSTOMER": "Customer-${user.id}",
      "CUSTOMERNAME": user.name,
      "CUSTOMEREMAIL": user.email,
      "CUSTOMERIP": "127.0.0.1",
      "CUSTOMERUSERAGENT": _resolveUserAgent(),
      "NAMEONCARD": _cardHolderCtrl.text.trim(),
      "CUSTOMERPHONE": user.phone ?? "",
      "ORDERITEMS": jsonEncode(orderItems),
      "BILLTOADDRESSLINE": billing?["full_address"]?.toString() ?? "",
      "BILLTOCITY": billing?["city"]?.toString() ?? "",
      "BILLTOCOUNTRY": _normalizeCountry(billing?["country"]?.toString()),
      "BILLTOPOSTALCODE": billing?["postal_code"]?.toString() ?? "",
      "BILLTOPHONE": user.phone ?? "",
      "SHIPTOADDRESSLINE": delivery?["full_address"]?.toString() ?? "",
      "SHIPTOCITY": delivery?["city"]?.toString() ?? "",
      "SHIPTOCOUNTRY": _normalizeCountry(delivery?["country"]?.toString()),
      "SHIPTOPOSTALCODE": delivery?["postal_code"]?.toString() ?? "",
      "SHIPTOPHONE": user.phone ?? "",
    };

    if (discountAmount > 0) {
      payload["discountAmount"] = discountAmount.toStringAsFixed(2);
    }

    return payload;
  }

  String _buildMerchantPaymentId(int userId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "Payment-$userId-$ts";
  }

  String _sanitizeCardNumber(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizeExpiry(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) return digits.substring(0, 4);
    return digits;
  }

  String _normalizeCountry(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return "TUR";
    final upper = value.toUpperCase();
    if (upper.contains("TUR")) return "TUR";
    if (upper.length == 3) return upper;
    if (upper.length == 2) return upper;
    return upper.length >= 3 ? upper.substring(0, 3) : upper;
  }

  String _resolveUserAgent() {
    if (kIsWeb) return "Web";
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "Android";
      case TargetPlatform.iOS:
        return "iOS";
      case TargetPlatform.fuchsia:
        return "Fuchsia";
      case TargetPlatform.linux:
        return "Linux";
      case TargetPlatform.macOS:
        return "macOS";
      case TargetPlatform.windows:
        return "Windows";
    }
  }

  /// Web için ödeme akışı: POST ile kart bilgileri gönderilir,
  /// dönen HTML'den 3D URL'i çıkarılır ve popup açılır.
  Future<PaymentResult?> _handleWebPayment(PaymentRedirectPayload payload, int orderId) async {
    try {
      // ignore: avoid_print
      print("🟦 PaymentScreen._handleWebPayment -> start");

      // POST kart bilgileriyle redirect endpoint'ine
      final redirectUri = _paymentService.redirectUri();
      final resp = await http.post(
        redirectUri,
        headers: {
          "content-type": "application/json",
          "x-api-key": PaymentConfig.apiKey,
        },
        body: jsonEncode(payload.toJson()),
      ).timeout(const Duration(seconds: 30));

      // ignore: avoid_print
      print("🟦 PaymentScreen._handleWebPayment -> response: ${resp.statusCode}");

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return PaymentResult(false, "3D ödeme sayfası yüklenemedi (${resp.statusCode})");
      }

      // Redirect response veya HTML dönebilir
      final location = resp.headers["location"];
      if (location != null && location.isNotEmpty) {
        // Direct redirect durumu - success/error URL'i olabilir
        if (location.contains("/payment/pay/success") || location.contains("/payment/pay/error")) {
          return _parseWebPaymentResult(location);
        }
        // 3D sayfa URL'ine redirect
        return await _openWebPaymentPopup(location);
      }

      // HTML döndüyse, içinden 3D URL'i veya form'u çıkar
      final body = resp.body;

      // 3D form action URL'sini bul (genellikle iframe veya form içinde)
      final actionMatch = RegExp('action=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(body);
      if (actionMatch != null) {
        final actionUrl = actionMatch.group(1)!;
        // ignore: avoid_print
        print("🟦 PaymentScreen._handleWebPayment -> found action: $actionUrl");
        return await _openWebPaymentPopup(actionUrl);
      }

      // iFrame src bul
      final iframeSrcMatch = RegExp('<iframe[^>]*src=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(body);
      if (iframeSrcMatch != null) {
        final iframeSrc = iframeSrcMatch.group(1)!;
        // ignore: avoid_print
        print("🟦 PaymentScreen._handleWebPayment -> found iframe src: $iframeSrc");
        return await _openWebPaymentPopup(iframeSrc);
      }

      // Direct HTML content - blob URL ile popup aç
      // ignore: avoid_print
      print("🟦 PaymentScreen._handleWebPayment -> opening popup with HTML content");
      return await _openWebPaymentPopupWithHtml(body);

    } catch (e) {
      // ignore: avoid_print
      print("🟥 PaymentScreen._handleWebPayment error: $e");
      return PaymentResult(false, "Ödeme işlemi başlatılamadı: $e");
    }
  }

  Future<PaymentResult?> _openWebPaymentPopup(String url) async {
    // ignore: avoid_print
    print("🟦 PaymentScreen._openWebPaymentPopup -> $url");
    final result = await openPaymentWindowAndWait(url);
    return result;
  }

  Future<PaymentResult?> _openWebPaymentPopupWithHtml(String htmlContent) async {
    // Web helper ile HTML blob URL'i oluşturup popup aç
    // Bu durumda polling mekanizması çalışacak
    final handle = openPaymentWindow("about:blank");
    if (handle == null) {
      return const PaymentResult(false, "Popup penceresi açılamadı. Lütfen popup engelleyiciyi kapatın.");
    }

    await loadPaymentHtml(handle, htmlContent);

    try {
      final result = await handle.onResult.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => const PaymentResult(false, "Ödeme zaman aşımına uğradı."),
      );
      return result;
    } catch (e) {
      handle.dispose();
      return PaymentResult(false, "Ödeme işlemi sırasında hata: $e");
    }
  }

  PaymentResult _parseWebPaymentResult(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const PaymentResult(false, "Ödeme sonucu okunamadı.");
    }

    final qp = uri.queryParameters;
    final responseCode = qp["responseCode"] ?? "";
    final responseMsg = _decodeWebParam(qp["responseMsg"]);
    final errorCode = qp["errorCode"];
    final errorMsg = _decodeWebParam(qp["errorMsg"]);
    final merchantPaymentId = qp["merchantPaymentId"] ?? qp["pgOrderId"];

    final isSuccess = responseCode == "00" || qp["approved"] == "true";

    return PaymentResult(
      isSuccess,
      isSuccess ? null : (errorMsg ?? responseMsg ?? "Ödeme başarısız."),
      approved: isSuccess,
      merchantPaymentId: merchantPaymentId,
      responseCode: responseCode,
      responseMsg: responseMsg,
      errorCode: errorCode,
      errorMsg: errorMsg,
    );
  }

  String? _decodeWebParam(String? raw) {
    if (raw == null) return null;
    final normalized = raw.replaceAll("+", " ");
    try {
      return Uri.decodeComponent(normalized);
    } catch (_) {
      return normalized;
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
    InputDecoration _inputDecoration(String label, {IconData? icon}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.red.shade400) : null,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
        ),
      );
    }

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
              decoration: _inputDecoration("Kart Üzerindeki İsim", icon: Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _cardNumberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                _CardNumberFormatter(),
                LengthLimitingTextInputFormatter(19),
              ],
              decoration: _inputDecoration("Kart Numarası", icon: Icons.credit_card),
              validator: (v) {
                final digits = _sanitizeCardNumber(v ?? "");
                return digits.length < 12 ? "Geçerli kart numarası girin" : null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryCtrl,
                    decoration: _inputDecoration("AA/YY", icon: Icons.event),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _ExpiryFormatter(),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    validator: (v) {
                      final digits = _normalizeExpiry(v ?? "");
                      return digits.length < 4 ? "Geçerli tarih girin" : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvCtrl,
                    decoration: _inputDecoration("CVV", icon: Icons.lock_outline),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (v) => (v == null || v.length != 3) ? "CVV girin" : null,
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
    if (periodRaw is int) {
      return DateTime(now.year, now.month + periodRaw, now.day);
    }
    if (periodRaw is num) {
      return DateTime(now.year, now.month + periodRaw.toInt(), now.day);
    }
    final period = periodRaw?.toString().toLowerCase();
    final parsed = int.tryParse(period ?? "");
    if (parsed != null && parsed > 0) {
      return DateTime(now.year, now.month + parsed, now.day);
    }
    if (period == "1m" || period == "1ay" || period == "1" || period == "1month") {
      return DateTime(now.year, now.month + 1, now.day);
    }
    if (period == "3m" || period == "3ay" || period == "3" || period == "3month") {
      return DateTime(now.year, now.month + 3, now.day);
    }
    if (period == "6m" || period == "6ay" || period == "6" || period == "6month") {
      return DateTime(now.year, now.month + 6, now.day);
    }
    if (period == "12m" || period == "12ay" || period == "12" || period == "12month" || period == "1y") {
      return DateTime(now.year, now.month + 12, now.day);
    }
    return null;
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      final isLast = i == limited.length - 1;
      if (!isLast && (i + 1) % 4 == 0) buffer.write(' ');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    String text;
    if (limited.length >= 3) {
      text = "${limited.substring(0, 2)}/${limited.substring(2)}";
    } else {
      text = limited;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
