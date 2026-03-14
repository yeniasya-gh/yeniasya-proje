import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/admin/admin_user_service.dart';
import 'package:YeniAsya/services/hasura_manager.dart';
import 'package:YeniAsya/utils/hash_helper.dart';

class _FakeHasuraManager implements HasuraManager {
  String? lastQuery;
  Map<String, dynamic>? lastVariables;

  @override
  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    lastQuery = query;
    lastVariables = variables;
    return {
      "insert_users_one": {"id": 1},
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
}
