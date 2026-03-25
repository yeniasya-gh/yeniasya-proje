import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:YeniAsya/services/auth/auth_api_service.dart';

void main() {
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
}
