import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/screen/admin/admin_passive_users_page.dart';
import 'package:YeniAsya/screen/admin/admin_users_page.dart';
import 'package:YeniAsya/services/admin/admin_user_service.dart';

class _FakeAdminUserService extends AdminUserService {
  _FakeAdminUserService(List<Map<String, dynamic>> seedUsers)
    : _users = List<Map<String, dynamic>>.from(seedUsers);

  final List<Map<String, dynamic>> _users;
  int getAllUsersCalls = 0;
  int getPassiveUsersCalls = 0;
  int addUserCalls = 0;
  int deleteUserCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    getAllUsersCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _users
        .where((item) => item["is_active"] != false)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRoles() async {
    return const [
      {"id": 1, "name": "User", "description": null},
      {"id": 2, "name": "Admin", "description": null},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getPassiveUsers() async {
    getPassiveUsersCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _users
        .where((item) => item["is_active"] == false)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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
      "is_active": true,
    });
    return true;
  }

  @override
  Future<bool> deleteUser(int id) async {
    deleteUserCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final index = _users.indexWhere((item) => item["id"] == id);
    if (index != -1) {
      _users[index] = {
        ..._users[index],
        "name": "Silinmiş Hesap",
        "email": "deleted_$id@example.local",
        "phone": null,
        "is_active": false,
        "deactivated_at": "2026-03-25T10:00:00Z",
      };
    }
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
        "is_active": true,
      },
      {
        "id": 2,
        "name": "Pasif Kullanıcı",
        "email": "pasif@example.com",
        "phone": "05551110000",
        "role_id": 1,
        "role": "User",
        "is_active": false,
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(adminService: fakeService)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("mevcut@example.com"), findsOneWidget);
    expect(find.text("pasif@example.com"), findsNothing);

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

  testWidgets("Kullanıcı silme önce onay ister", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeService = _FakeAdminUserService([
      {
        "id": 1,
        "name": "Silinecek Kullanıcı",
        "email": "silinecek@example.com",
        "phone": "05550000000",
        "role_id": 1,
        "role": "User",
        "is_active": true,
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(adminService: fakeService)),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byIcon(Icons.delete).first;
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text("Kullanıcı pasif hale getirilsin mi?"), findsOneWidget);
    expect(fakeService.deleteUserCalls, 0);
    expect(find.textContaining("pasif hale getirilecek"), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, "Pasife Al"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeService.deleteUserCalls, 1);
    expect(find.text("Silinecek Kullanıcı"), findsNothing);
    expect(find.text("silinecek@example.com"), findsNothing);
    expect(find.text("Kullanıcı pasif hale getirildi"), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets("Pasif kullanıcılar butonu pasif kullanıcı sayfasını açar", (
    tester,
  ) async {
    final fakeService = _FakeAdminUserService([
      {
        "id": 1,
        "name": "Aktif Kullanıcı",
        "email": "aktif@example.com",
        "phone": "05550000000",
        "role_id": 1,
        "role": "User",
        "is_active": true,
      },
      {
        "id": 2,
        "name": "Pasif Kullanıcı",
        "email": "pasif@example.com",
        "phone": "05551110000",
        "role_id": 1,
        "role": "User",
        "is_active": false,
        "deactivated_at": "2026-03-25T10:00:00Z",
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(adminService: fakeService)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Pasif Kullanıcılar"));
    await tester.pumpAndSettle();

    expect(find.byType(AdminPassiveUsersPage), findsOneWidget);
    expect(find.text("Pasif Kullanıcılar"), findsWidgets);
    expect(find.textContaining("pasif@example.com"), findsOneWidget);
    expect(fakeService.getPassiveUsersCalls, greaterThanOrEqualTo(1));
  });
}
