import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:YeniAsya/services/auth/auth_api_service.dart';
import 'package:YeniAsya/services/auth/auth_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'auth_expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });
    await AuthTokenStore.load();
  });

  tearDown(() async {
    await AuthTokenStore.clear();
  });

  test('AuthApiService.register lowercases email before sending', () async {
    Map<String, dynamic>? payload;
    final client = MockClient((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"ok":true}', 200);
    });

    final service = AuthApiService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    await service.register(
      name: 'Test User',
      email: 'Test@Example.COM',
      password: 'Secret123',
    );

    expect(payload?['email'], 'test@example.com');
  });

  test('AuthApiService.register surfaces old manual newspaper accounts', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"ok":false,"code":"OLD_MANUAL_NEWSPAPER_ACCOUNT","error":"Bu e-posta eski e-gazete aboneliğine ait."}',
        409,
      );
    });

    final service = AuthApiService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    expect(
      service.register(
        name: 'Test User',
        email: 'old@example.com',
        password: 'Secret123',
      ),
      throwsA(
        predicate((error) => error.toString().contains('OLD_MANUAL_NEWSPAPER_ACCOUNT')),
      ),
    );
  });

  test('AuthApiService.login lowercases email before sending', () async {
    Map<String, dynamic>? payload;
    final client = MockClient((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"ok":true,"user":{"id":1}}', 200);
    });

    final service = AuthApiService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    await service.login(email: 'Login@Test.COM', password: 'Secret123');

    expect(payload?['email'], 'login@test.com');
  });

  test('AuthApiService.getMe surfaces session revoked code', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"ok":false,"code":"SESSION_REVOKED","error":"Oturumunuz sonlandırıldı."}',
        401,
      );
    });

    final service = AuthApiService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    expect(
      service.getMe(),
      throwsA(
        predicate((error) => error.toString().contains('SESSION_REVOKED')),
      ),
    );
  });
}
