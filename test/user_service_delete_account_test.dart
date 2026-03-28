import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/services/auth/user_service.dart';
import 'package:YeniAsya/services/hasura_manager.dart';

class _FakeHasuraManager implements HasuraManager {
  final List<String> queries = [];
  Map<String, dynamic>? lastVariables;

  @override
  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    queries.add(query);
    lastVariables = variables;

    if (query.contains("delete_users_by_pk")) {
      return {"delete_users_by_pk": null};
    }
    if (query.contains("update_users_by_pk")) {
      return {
        "update_users_by_pk": {
          "id": variables?["id"],
        },
      };
    }
    return {};
  }
}

void main() {
  test("UserService.deleteAccount falls back without deactivated_at", () async {
    final fakeHasura = _FakeHasuraManager();
    final service = UserService(hasura: fakeHasura);

    final deleted = await service.deleteAccount(id: 10);

    expect(deleted, isTrue);
    expect(fakeHasura.queries.length, 2);
    expect(fakeHasura.queries.first, contains("delete_users_by_pk"));
    expect(fakeHasura.queries.last, contains("update_users_by_pk"));
    expect(
      fakeHasura.queries.any((query) => query.contains("deactivated_at")),
      isFalse,
    );
    expect(fakeHasura.lastVariables?["id"], 10);
  });
}
