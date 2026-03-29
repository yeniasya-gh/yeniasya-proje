import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/admin/admin_user_service.dart';
import 'package:YeniAsya/services/hasura_manager.dart';
import 'package:YeniAsya/utils/hash_helper.dart';

class _FakeHasuraManager implements HasuraManager {
  String? lastQuery;
  Map<String, dynamic>? lastVariables;
  final List<String> queries = [];
  int callCount = 0;

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
    return {
      if (query.contains("insert_users_one")) "insert_users_one": {"id": 1},
      if (query.contains("update_users_by_pk")) "update_users_by_pk": {"id": 1},
      if (query.contains("update_user_content_access"))
        "update_user_content_access": {"affected_rows": 1},
      if (query.contains("update_manual_newspaper_users"))
        "update_manual_newspaper_users": {"affected_rows": 1},
      if (query.contains("query GetUserAccess") ||
          query.contains("query GetUserAccessAll") ||
          query.contains("user_content_access"))
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

  test("AdminUserService.deleteUser only deactivates the user", () async {
    final fakeHasura = _FakeHasuraManager();
    final service = AdminUserService(hasura: fakeHasura);

    final deleted = await service.deleteUser(42);

    expect(deleted, true);
    expect(fakeHasura.callCount, 1);
    expect(fakeHasura.lastQuery, contains("update_users_by_pk"));
    expect(fakeHasura.lastQuery, contains("is_active: false"));
    expect(fakeHasura.lastQuery, contains("deactivated_at"));
    expect(fakeHasura.lastQuery, isNot(contains("deleted_42_")));
    expect(fakeHasura.lastQuery, isNot(contains("phone: null")));
    expect(fakeHasura.lastQuery, isNot(contains("email_verified_at")));
    expect(fakeHasura.lastQuery, isNot(contains("firebase_token")));
  });

  test(
    "AdminUserService.deleteUser remains a single deactivate mutation",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = AdminUserService(hasura: fakeHasura);

      final deleted = await service.deleteUser(42);

      expect(deleted, true);
      expect(fakeHasura.callCount, 1);
      expect(fakeHasura.lastVariables?["id"], 42);
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

  test(
    "AdminUserService.deactivateAccessEntry deactivates user content access rows",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = AdminUserService(hasura: fakeHasura);

      await service.deactivateAccessEntry({
        "id": 99,
        "item_type": "book",
        "item_id": 12,
        "source": "user_content_access",
      });

      expect(fakeHasura.queries.last, contains("update_user_content_access"));
      expect(fakeHasura.lastVariables?["id"], 99);
    },
  );

  test(
    "AdminUserService.deactivateAccessEntry deactivates manual newspaper rows even when source is inferred",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final service = AdminUserService(hasura: fakeHasura);

      await service.deactivateAccessEntry({"id": "manual_77", "source_id": 77});

      expect(
        fakeHasura.queries.last,
        contains("update_manual_newspaper_users"),
      );
      expect(fakeHasura.lastVariables?["id"], "77");
    },
  );
}
