import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:YeniAsya/services/admin/admin_magazine_service.dart';

void main() {
  test('getPublicIssues reads public CDN endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://cdn.example.com/magazines/42/issues/public',
      );
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {
              'id': 7,
              'magazine_id': 42,
              'issue_number': 12,
              'photo_url': 'https://cdn.example.com/issue.jpg',
              'price': '25.00',
              'description': 'Test issue',
              'added_at': '2026-03-17',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = AdminMagazineService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    final issues = await service.getPublicIssues(42);

    expect(issues, hasLength(1));
    expect(issues.first['magazine_id'], 42);
    expect(issues.first['issue_number'], 12);
  });
}
