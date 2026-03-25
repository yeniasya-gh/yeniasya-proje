import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/admin/admin_user_service.dart';
import 'package:YeniAsya/services/hasura_manager.dart';
import 'package:YeniAsya/utils/hash_helper.dart';

class _FakeHasuraManager implements HasuraManager {
  String? lastQuery;
  Map<String, dynamic>? lastVariables;
  final List<String> queries = [];
  int callCount = 0;
  bool failRelatedCleanup = false;

  @override
  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    lastQuery = query;
    lastVariables = variables;
    queries.add(query);
    callCount += 1;
    if (failRelatedCleanup && query.contains("delete_order_items")) {
      throw Exception("constraint-violation");
    }
    return {
      if (query.contains("insert_users_one")) "insert_users_one": {"id": 1},
      if (query.contains("update_users_by_pk")) "update_users_by_pk": {"id": 1},
      if (query.contains("delete_order_items"))
        "delete_order_items": {"affected_rows": 1},
      if (query.contains("delete_orders"))
        "delete_orders": {"affected_rows": 1},
      if (query.contains("delete_notifications"))
        "delete_notifications": {"affected_rows": 1},
      if (query.contains("delete_contact_messages"))
        "delete_contact_messages": {"affected_rows": 1},
      if (query.contains("delete_product_reviews"))
        "delete_product_reviews": {"affected_rows": 1},
      if (query.contains("delete_user_access_audit_log"))
        "delete_user_access_audit_log": {"affected_rows": 1},
      if (query.contains("delete_user_addresses"))
        "delete_user_addresses": {"affected_rows": 1},
      if (query.contains("delete_user_content_access"))
        "delete_user_content_access": {"affected_rows": 1},
      if (query.contains("delete_manual_newspaper_users"))
        "delete_manual_newspaper_users": {"affected_rows": 1},
      if (query.contains("delete_email_verification_tokens"))
        "delete_email_verification_tokens": {"affected_rows": 1},
      if (query.contains("delete_password_reset_tokens"))
        "delete_password_reset_tokens": {"affected_rows": 1},
      if (query.contains("user_content_access"))
        "user_content_access": const [],
      if (query.contains("is_active: {_eq: false}"))
        "users": [
          {
            "id": 77,
            "name": "Pasif Kullanıcı",
            "email": "pasif@example.com",
            "phone": "05550000000",
            "role_id": 1,
            "is_active": false,
            "deactivated_at": "2026-03-25T10:00:00Z",
            "email_verified_at": "2026-03-24T10:00:00Z",
            "role": {"name": "User"},
          },
        ],
      if (query.contains("deactivated_at"))
        "users_by_pk": {
          "id": 1,
          "name": "Silinmiş Hesap",
          "email": "deleted@example.local",
          "phone": null,
          "role_id": 1,
          "role": {"name": "User"},
          "avatar_url": null,
          "payUniqe": null,
          "is_active": false,
          "email_verified_at": null,
          "deactivated_at": "2026-03-25T10:00:00Z",
        },
    };
  }
}

void main() {
  test(
    "AdminUserService.addUser hashes password and marks new user verified",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = AdminUserService(hasura: fakeHasura);

      await service.addUser(
        name: "  Yeni Kullanıcı  ",
        email: "  TEST@EXAMPLE.COM  ",
        password: "Sifre123",
        phone: " 05551234567 ",
      );

      expect(
        fakeHasura.lastVariables?["password"],
        HashHelper.hashPassword("Sifre123"),
      );
      expect(fakeHasura.lastVariables?["name"], "Yeni Kullanıcı");
      expect(fakeHasura.lastVariables?["email"], "test@example.com");
      expect(fakeHasura.lastVariables?["phone"], "05551234567");
      expect(fakeHasura.lastVariables?["is_active"], true);
      expect(
        DateTime.tryParse(
          fakeHasura.lastVariables?["email_verified_at"]?.toString() ?? "",
        ),
        isNotNull,
      );
      expect(fakeHasura.lastQuery, contains("is_active"));
      expect(fakeHasura.lastQuery, contains("email_verified_at"));
    },
  );

  test("AdminUserService.deleteUser soft-deletes user after cleanup", () async {
    final fakeHasura = _FakeHasuraManager();
    final service = AdminUserService(hasura: fakeHasura);

    final deleted = await service.deleteUser(42);

    expect(deleted, true);
    expect(fakeHasura.callCount, 2);
    expect(fakeHasura.queries.first, contains("delete_order_items"));
    expect(fakeHasura.queries.first, contains("delete_user_addresses"));
    expect(fakeHasura.queries.first, contains("delete_user_content_access"));
    expect(fakeHasura.queries[1], contains("update_users_by_pk"));
    expect(fakeHasura.lastQuery, contains("update_users_by_pk"));
    expect(fakeHasura.lastQuery, contains("is_active: false"));
    expect(fakeHasura.lastQuery, contains("deactivated_at"));
  });

  test(
    "AdminUserService.deleteUser still soft-deletes when cleanup fails",
    () async {
      final fakeHasura = _FakeHasuraManager()..failRelatedCleanup = true;
      final service = AdminUserService(hasura: fakeHasura);

      final deleted = await service.deleteUser(42);

      expect(deleted, true);
      expect(fakeHasura.callCount, 2);
      expect(fakeHasura.queries.first, contains("delete_order_items"));
      expect(fakeHasura.queries[1], contains("update_users_by_pk"));
      expect(fakeHasura.lastVariables?["id"], 42);
      expect(fakeHasura.lastVariables?["name"], "Silinmiş Hesap");
      expect(fakeHasura.lastVariables?["email"], contains("deleted_42_"));
      expect(fakeHasura.lastVariables?["password"], isNotNull);
      expect(fakeHasura.lastQuery, contains("is_active: false"));
      expect(fakeHasura.lastQuery, contains("deactivated_at"));
    },
  );

  test(
    "AdminUserService.getAllAccess requests access channel columns",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = AdminUserService(hasura: fakeHasura);

      final access = await service.getAllAccess(42);

      expect(access, isEmpty);
      expect(
        fakeHasura.queries.any((query) => query.contains("grant_source")),
        true,
      );
      expect(
        fakeHasura.queries.any((query) => query.contains("purchase_platform")),
        true,
      );
    },
  );

  test(
    "AdminUserService.getPassiveUsers requests deactivated_at and returns passive users",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = AdminUserService(hasura: fakeHasura);

      final passiveUsers = await service.getPassiveUsers();

      expect(passiveUsers, isNotEmpty);
      expect(passiveUsers.first["is_active"], false);
      expect(passiveUsers.first["deactivated_at"], isNotNull);
      expect(
        fakeHasura.queries.any((query) => query.contains("deactivated_at")),
        true,
      );
      expect(
        fakeHasura.queries.any(
          (query) => query.contains("is_active: {_eq: false}"),
        ),
        true,
      );
    },
  );
}
