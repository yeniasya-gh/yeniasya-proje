import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/revenuecat_config.dart';
import '../../helpers/payment_web_pending_store.dart';
import '../../services/access_provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/cart/cart_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/mail_manager.dart';
import '../../services/order_service.dart';
import '../../services/promo_code_service.dart';
import '../../services/revenuecat_backend_service.dart';
import '../../services/user_content_access_service.dart';
import 'order_success_screen.dart';
import 'payment_webview_screen.dart';

class PaymentWebReturnScreen extends StatefulWidget {
  final Uri resultUri;

  const PaymentWebReturnScreen({super.key, required this.resultUri});

  @override
  State<PaymentWebReturnScreen> createState() => _PaymentWebReturnScreenState();
}

class _PaymentWebReturnScreenState extends State<PaymentWebReturnScreen> {
  final _orderService = OrderService();
  final _accessService = UserContentAccessService();
  final _promoService = PromoCodeService();
  final _revenueCatBackendService = RevenueCatBackendService();

  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _processReturn();
  }

  Future<void> _processReturn() async {
    final result = _parseResult(widget.resultUri);
    final pending = await PaymentWebPendingStore.load();

    try {
      if (pending != null && pending.orderId > 0) {
        await _orderService.updateOrderPaymentStatus(
          orderId: pending.orderId,
          status: result.success ? "paid" : "pending",
          paymentApproved: result.success,
          paymentResponseCode: result.responseCode,
          paymentResponseMsg: result.responseMsg,
          paymentErrorCode: result.errorCode,
          paymentErrorMsg: result.errorMsg ?? result.message,
        );

        if (result.success) {
          final mailWarning = await _finalizeOrder(pending);
          await PaymentWebPendingStore.clear();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => OrderSuccessScreen(
                orderId: pending.orderId.toString(),
                total: pending.payableTotal.toStringAsFixed(2),
                mailWarning: mailWarning,
              ),
            ),
            (route) => route.isFirst,
          );
          return;
        }
      }

      await PaymentWebPendingStore.clear();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = result.success
            ? "Ödeme tamamlandı."
            : result.message ?? "Ödeme tamamlanamadı.";
      });
    } catch (e) {
      await PaymentWebPendingStore.clear();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = ErrorManager.parseGraphQLError(e.toString());
      });
    }
  }

  PaymentResult _parseResult(Uri uri) {
    final qp = uri.queryParameters;
    final map = <String, dynamic>{
      "approved": qp["approved"] == "true" || qp["responseCode"] == "00",
      "responseCode": qp["responseCode"] ?? qp["code"],
      "responseMsg": qp["responseMsg"] ?? qp["message"],
      "errorCode": qp["errorCode"],
      "errorMsg": qp["errorMsg"],
      "merchantPaymentId": qp["merchantPaymentId"] ?? qp["pgOrderId"],
    };
    return PaymentResult.fromJson(map);
  }

  Future<String?> _finalizeOrder(PendingWebPayment pending) async {
    String? mailWarning;

    final directAccessItems = pending.accessItems
        .where((item) => item["item_type"] != "newspaper_subscription")
        .toList();
    final newspaperAccessItems = pending.accessItems
        .where((item) => item["item_type"] == "newspaper_subscription")
        .toList();

    if (directAccessItems.isNotEmpty) {
      await _accessService.grantAccess(
        userId: pending.userId,
        items: directAccessItems,
      );
    }

    if (newspaperAccessItems.isNotEmpty) {
      final synced = await _syncNewspaperSubscriptionWithRevenueCat(
        pending: pending,
        newspaperAccessItems: newspaperAccessItems,
      );
      if (!synced) {
        await _accessService.grantAccess(
          userId: pending.userId,
          items: newspaperAccessItems,
        );
      }
    }

    if (pending.promoId != null) {
      await _promoService.markUsed(pending.promoId!);
    }

    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        await MailManager.instance.sendOrderSummary(
          to: user.email,
          name: user.name,
          orderId: pending.orderId.toString(),
          total: pending.payableTotal,
          items: pending.itemsPayload,
        );
      }
    } catch (e) {
      if (e is MailDeliveryException) {
        mailWarning = e.userMessage;
      } else {
        mailWarning = "Bilgilendirme e-postası gönderilemedi.";
      }
    }

    final access = context.read<AccessProvider>();
    final uid = int.tryParse(pending.userId);
    if (uid != null) {
      await access.load(uid);
    }

    context.read<CartProvider>().clear();
    return mailWarning;
  }

  Future<bool> _syncNewspaperSubscriptionWithRevenueCat({
    required PendingWebPayment pending,
    required List<Map<String, dynamic>> newspaperAccessItems,
  }) async {
    if (newspaperAccessItems.isEmpty) return true;

    String? expiresAt;
    for (final item in newspaperAccessItems) {
      final raw = item["expires_at"]?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        expiresAt = raw;
        break;
      }
    }

    try {
      final user = context.read<AuthProvider>().user;
      await _revenueCatBackendService.grantSubscription(
        source: "web_checkout",
        entitlementId: RevenueCatConfig.entitlementYeniasyaPro,
        userId: int.tryParse(pending.userId),
        appUserId: user?.revenueCatUserId,
        expirationDate: expiresAt,
        lifetime: expiresAt == null,
        purchasePlatform: "paratika",
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Ödeme Sonucu"),
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 20),
                Text(
                  _message ?? "Ödeme tamamlanamadı.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("Ana Sayfaya Dön"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
