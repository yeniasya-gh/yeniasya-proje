import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/utils/admin_user_detail_metrics.dart';

void main() {
  group('AdminUserDetailMetrics', () {
    test('content summary counts duplicate subscriptions separately', () {
      final access = [
        {
          "item_type": "magazine",
          "item_title": "Haftalık Dergi",
          "started_at": "2026-01-01T00:00:00.000Z",
          "expires_at": "2026-01-31T00:00:00.000Z",
        },
        {
          "item_type": "magazine",
          "item_title": "Haftalık Dergi",
          "started_at": "2026-02-01T00:00:00.000Z",
          "expires_at": "2026-05-02T00:00:00.000Z",
        },
        {
          "item_type": "newspaper_subscription",
          "item_title": "Günlük Gazete",
          "item_subtitle": "Premium",
          "started_at": "2026-03-01T00:00:00.000Z",
          "expires_at": "2026-03-31T00:00:00.000Z",
        },
      ];

      final summary = AdminUserDetailMetrics.buildContentSummary(access);

      expect(summary, hasLength(2));

      final magazine = summary.firstWhere(
        (item) => item["title"] == "Haftalık Dergi",
      );
      expect(magazine["count"], 2);
      expect((magazine["names"] as List<String>).join(" | "), contains("1 ay"));
      expect((magazine["names"] as List<String>).join(" | "), contains("3 ay"));

      final newspaper = summary.firstWhere(
        (item) => item["title"] == "Günlük Gazete",
      );
      expect(newspaper["count"], 1);
      expect((newspaper["names"] as List<String>).first, contains("Premium"));
    });

    test('order stats count completed statuses beyond paid', () {
      final stats = AdminUserDetailMetrics.buildOrderStats([
        {"status": "paid", "total_paid": 10},
        {"status": "pending", "total_paid": 20},
        {"status": "failed", "total_paid": 30},
        {"status": "shipped", "total_paid": 40},
      ]);

      expect(stats["total"], 4);
      expect(stats["completed"], 2);
      expect(stats["pending"], 1);
      expect(stats["failed"], 1);
      expect(stats["totalPaid"], 100.0);
    });

    test('visible orders are sorted newest first', () {
      final sorted = AdminUserDetailMetrics.buildVisibleOrders([
        {"id": 1, "created_at": "2026-03-01T10:00:00.000Z"},
        {"id": 2, "created_at": "2026-03-03T10:00:00.000Z"},
        {"id": 3, "created_at": "2026-03-02T10:00:00.000Z"},
      ]);

      expect(sorted.map((o) => o["id"]), [2, 3, 1]);
    });
  });
}
