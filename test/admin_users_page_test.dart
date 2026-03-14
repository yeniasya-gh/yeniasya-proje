import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/screen/admin/admin_users_page.dart';
import 'package:YeniAsya/services/admin/admin_user_service.dart';

class _FakeAdminUserService extends AdminUserService {
  _FakeAdminUserService(List<Map<String, dynamic>> seedUsers)
    : _users = List<Map<String, dynamic>>.from(seedUsers);

  final List<Map<String, dynamic>> _users;
  int getAllUsersCalls = 0;
  int addUserCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    getAllUsersCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _users.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRoles() async {
    return const [
      {"id": 1, "name": "User", "description": null},
      {"id": 2, "name": "Admin", "description": null},
    ];
  }

  @override
  Future<bool> addUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    int roleId = 1,
  }) async {
    addUserCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _users.add({
      "id": _users.length + 1,
      "name": name,
      "email": email,
      "phone": phone,
      "role_id": roleId,
      "role": roleId == 2 ? "Admin" : "User",
    });
    return true;
  }
}

void main() {
  testWidgets("Yeni kullanıcı ekleme sonrası liste yenilenir", (tester) async {
    final fakeService = _FakeAdminUserService([
      {
        "id": 1,
        "name": "Mevcut Kullanıcı",
        "email": "mevcut@example.com",
        "phone": "05550000000",
        "role_id": 1,
        "role": "User",
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(adminService: fakeService)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("mevcut@example.com"), findsOneWidget);

    await tester.tap(find.text("Kullanıcı Ekle").first);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));

    await tester.enterText(fields.at(0), "Yeni Kullanıcı");
    await tester.enterText(fields.at(1), "yeni@example.com");
    await tester.enterText(fields.at(2), "05551112233");
    await tester.enterText(fields.at(3), "Sifre123");

    await tester.tap(find.widgetWithText(ElevatedButton, "Kaydet"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeService.addUserCalls, 1);
    expect(fakeService.getAllUsersCalls, greaterThanOrEqualTo(2));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text("yeni@example.com"), findsOneWidget);
    expect(
      find.text("Kullanıcı eklendi ve liste güncellendi."),
      findsOneWidget,
    );
  });
}
