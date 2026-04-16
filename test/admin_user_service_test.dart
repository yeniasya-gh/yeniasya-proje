import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/admin/admin_user_service.dart';
import 'package:YeniAsya/services/cdn_authenticated_client.dart';
import 'package:YeniAsya/services/hasura_manager.dart';
import 'package:YeniAsya/utils/hash_helper.dart';

class _FakeCdnClient extends CdnAuthenticatedClient {
  _FakeCdnClient({Map<String, dynamic>? purgeResponse})
    : purgeResponse =
          purgeResponse ??
          {
            "ok": true,
            "deletedUserIds": [77],
            "deletedCount": 10,
            "deletedCounts": {"users": 1},
          };

  final List<Map<String, dynamic>> calls = [];
  final Map<String, dynamic> purgeResponse;

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    calls.add({"path": path, "body": body});
    if (path != "/admin/users/purge") {
      if (path != "/admin/users/revenuecat/reconcile") {
        throw StateError("Unexpected CDN path: $path");
      }
    }
    return purgeResponse;
  }
}

class _FakeHasuraManager implements HasuraManager {
  _FakeHasuraManager({
    this.throwDuplicateOnInsert = false,
    this.duplicateInsertAttemptsRemaining,
  });

  String? lastQuery;
  Map<String, dynamic>? lastVariables;
  final List<String> queries = [];
  int callCount = 0;
  final bool throwDuplicateOnInsert;
  int? duplicateInsertAttemptsRemaining;

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
    final remaining =
        duplicateInsertAttemptsRemaining ?? (throwDuplicateOnInsert ? 1 : 0);
    if (query.contains("insert_users_one") && remaining > 0) {
      duplicateInsertAttemptsRemaining = remaining - 1;
      throw Exception(
        'Uniqueness violation. duplicate key value violates unique constraint "users_email_key"',
      );
    }

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

  test(
    "AdminUserService.addUser purges passive user when duplicate email exists",
    () async {
      final fakeHasura = _FakeHasuraManager(
        throwDuplicateOnInsert: true,
        duplicateInsertAttemptsRemaining: 1,
      );
      final fakeCdn = _FakeCdnClient();
      final service = AdminUserService(hasura: fakeHasura, cdnClient: fakeCdn);

      final ok = await service.addUser(
        name: "  Celal SağıR  ",
        email: "  celalsagir4427@gmail.com  ",
        password: "Abonelik123",
        phone: " 5057769777 ",
        roleId: 2,
      );

      expect(ok, true);
      expect(
        fakeHasura.queries
            .where((query) => query.contains("insert_users_one"))
            .length,
        2,
      );
      expect(fakeCdn.calls.length, 1);
      expect(fakeCdn.calls.single["path"], "/admin/users/purge");
      expect(fakeCdn.calls.single["body"], {
        "email": "celalsagir4427@gmail.com",
        "phone": "5057769777",
      });
      expect(fakeHasura.lastQuery, contains("insert_users_one"));
      expect(fakeHasura.lastVariables?["email"], "celalsagir4427@gmail.com");
      expect(fakeHasura.lastVariables?["phone"], "5057769777");
      expect(fakeHasura.lastVariables?["role_id"], 2);
      expect(fakeHasura.lastVariables?["password"], isNotEmpty);
      expect(
        DateTime.tryParse(
          fakeHasura.lastVariables?["email_verified_at"]?.toString() ?? "",
        ),
        isNotNull,
      );
    },
  );

  test("AdminUserService.hardDeleteUser purges passive user by id", () async {
    final fakeHasura = _FakeHasuraManager();
    final fakeCdn = _FakeCdnClient();
    final service = AdminUserService(hasura: fakeHasura, cdnClient: fakeCdn);

    await service.hardDeleteUser(42);

    expect(fakeCdn.calls.length, 1);
    expect(fakeCdn.calls.single["path"], "/admin/users/purge");
    expect(fakeCdn.calls.single["body"], {"userId": 42});
  });

  test(
    "AdminUserService.reconcileRevenueCatSubscription posts reconcile request",
    () async {
      final fakeHasura = _FakeHasuraManager();
      final fakeCdn = _FakeCdnClient(
        purgeResponse: {
          "ok": true,
          "fixed": true,
          "activeRevenueCat": true,
          "activeAccessBefore": false,
          "activeAccessAfter": true,
          "payUniqeUpdated": true,
          "matchedAppUserId": "debae21d-cd46-4070-a40a-e7b4d178d296",
          "message":
              "RevenueCat aktif abonelik bulundu ve sistem kaydı düzeltildi.",
        },
      );
      final service = AdminUserService(hasura: fakeHasura, cdnClient: fakeCdn);

      final result = await service.reconcileRevenueCatSubscription(userId: 907);

      expect(fakeCdn.calls.length, 1);
      expect(fakeCdn.calls.single["path"], "/admin/users/revenuecat/reconcile");
      expect(fakeCdn.calls.single["body"], {"userId": 907});
      expect(result["fixed"], true);
      expect(result["activeRevenueCat"], true);
      expect(result["payUniqeUpdated"], true);
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
