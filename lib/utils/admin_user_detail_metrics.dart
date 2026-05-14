class AdminUserDetailMetrics {
  static int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  static String accessTypeLabel(String type) {
    switch (type) {
      case "book":
        return "Kitap";
      case "magazine":
        return "E-dergi";
      case "magazine_issue":
        return "Dergi Sayısı";
      case "newspaper_subscription":
        return "Gazete Aboneliği";
      case "ek":
        return "Ek";
      default:
        return type;
    }
  }

  static List<Map<String, dynamic>> buildContentSummary(
    List<Map<String, dynamic>> access,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final item in access) {
      final type =
          item["item_type_label"]?.toString() ??
          accessTypeLabel((item["item_type"] ?? "").toString());
      final channel = item["access_channel_label"]?.toString().trim() ?? "";
      final titleBase = item["item_title"]?.toString().trim().isNotEmpty == true
          ? item["item_title"].toString().trim()
          : type;
      final title = channel.isNotEmpty && channel != "Bilinmiyor"
          ? "$titleBase • $channel"
          : titleBase;
      final key = [type, channel, titleBase].join("::");
      final name = accessDisplayLabel(item, fallbackType: type);
      final group = grouped.putIfAbsent(
        key,
        () => {"title": title, "names": <String>[], "count": 0},
      );
      group["count"] = _intValue(group["count"]) + 1;
      (group["names"] as List<String>).add(name);
    }

    final summary = grouped.values
        .map(
          (group) => {
            "title": group["title"],
            "names": (group["names"] as List<String>)..sort(),
            "count": group["count"],
          },
        )
        .toList(growable: false);
    summary.sort(
      (a, b) => (a["title"]?.toString() ?? "").compareTo(
        b["title"]?.toString() ?? "",
      ),
    );
    return summary;
  }

  static List<Map<String, dynamic>> buildVisibleOrders(
    List<Map<String, dynamic>> orders,
  ) {
    final visibleOrders = List<Map<String, dynamic>>.from(orders);
    visibleOrders.sort((a, b) {
      final aDate =
          _parseDate(a["created_at"]) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          _parseDate(b["created_at"]) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return visibleOrders;
  }

  static Map<String, dynamic> buildOrderStats(
    List<Map<String, dynamic>> orders,
  ) {
    final stats = <String, dynamic>{
      "total": orders.length,
      "completed": 0,
      "pending": 0,
      "failed": 0,
      "totalPaid": 0.0,
    };

    for (final order in orders) {
      final status = (order["status"] ?? "paid").toString().toLowerCase();
      if (isCompletedOrderStatus(status)) {
        stats["completed"] = _intValue(stats["completed"]) + 1;
      } else if (status == "pending") {
        stats["pending"] = _intValue(stats["pending"]) + 1;
      } else {
        stats["failed"] = _intValue(stats["failed"]) + 1;
      }

      final total = double.tryParse(order["total_paid"]?.toString() ?? "") ?? 0;
      stats["totalPaid"] = (stats["totalPaid"] as num).toDouble() + total;
    }

    return stats;
  }

  static bool isCompletedOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case "paid":
      case "success":
      case "completed":
      case "shipped":
      case "delivered":
        return true;
      default:
        return false;
    }
  }

  static String accessDisplayLabel(
    Map<String, dynamic> item, {
    required String fallbackType,
  }) {
    final title = item["item_title"]?.toString().trim().isNotEmpty == true
        ? item["item_title"].toString().trim()
        : fallbackType;
    final subtitle = item["item_subtitle"]?.toString().trim();
    final period = accessPeriodLabel(item);
    final parts = <String>[title];
    if (subtitle != null && subtitle.isNotEmpty) parts.add(subtitle);
    if (period != null && period.isNotEmpty && period != subtitle) {
      parts.add(period);
    }
    return parts.join(" • ");
  }

  static String? accessPeriodLabel(Map<String, dynamic> item) {
    final started = _parseDate(item["started_at"]);
    final expires = _parseDate(item["expires_at"]);
    if (started == null || expires == null) return null;
    final duration = expires.difference(started);
    if (duration.isNegative || duration.inDays <= 0) return null;
    final days = duration.inDays;
    if (days % 30 == 0) {
      final months = days ~/ 30;
      return months == 1 ? "1 ay" : "$months ay";
    }
    if (days % 7 == 0 && days >= 14) {
      final weeks = days ~/ 7;
      return weeks == 1 ? "1 hafta" : "$weeks hafta";
    }
    return days == 1 ? "1 gün" : "$days gün";
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}
