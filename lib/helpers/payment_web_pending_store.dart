import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingWebPayment {
  final int orderId;
  final String userId;
  final double payableTotal;
  final int? promoId;
  final List<Map<String, dynamic>> itemsPayload;
  final List<Map<String, dynamic>> accessItems;

  const PendingWebPayment({
    required this.orderId,
    required this.userId,
    required this.payableTotal,
    required this.itemsPayload,
    required this.accessItems,
    this.promoId,
  });

  Map<String, dynamic> toJson() {
    return {
      "orderId": orderId,
      "userId": userId,
      "payableTotal": payableTotal,
      "promoId": promoId,
      "itemsPayload": itemsPayload,
      "accessItems": accessItems,
    };
  }

  factory PendingWebPayment.fromJson(Map<String, dynamic> json) {
    return PendingWebPayment(
      orderId: (json["orderId"] as num?)?.toInt() ?? 0,
      userId: json["userId"]?.toString() ?? "",
      payableTotal: (json["payableTotal"] as num?)?.toDouble() ?? 0,
      promoId: (json["promoId"] as num?)?.toInt(),
      itemsPayload: List<Map<String, dynamic>>.from(
        (json["itemsPayload"] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      accessItems: List<Map<String, dynamic>>.from(
        (json["accessItems"] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
    );
  }
}

class PaymentWebPendingStore {
  static const _storageKey = "pending_web_payment_v1";

  static Future<void> save(PendingWebPayment pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(pending.toJson()));
  }

  static Future<PendingWebPayment?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PendingWebPayment.fromJson(decoded);
      }
      if (decoded is Map) {
        return PendingWebPayment.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}

    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
