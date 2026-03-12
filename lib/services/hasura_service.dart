import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth/auth_token_store.dart';

class HasuraService {
  HasuraService({http.Client? client}) : _client = client ?? http.Client();

  static const String endpoint = String.fromEnvironment(
    "HASURA_ENDPOINT",
    defaultValue: "https://cdn.yeniasyadigital.com/hasura",
  );
  static final Uri endpointUri = Uri.parse(endpoint);
  static const Duration timeout = Duration(seconds: 20);

  final http.Client _client;

  Future<http.Response> post({
    required String query,
    Map<String, dynamic>? variables,
    String? operationName,
    Duration? timeoutOverride,
  }) {
    final token = AuthTokenStore.token?.trim();
    if (token == null || token.isEmpty) {
      throw Exception("Hasura token bulunamadı.");
    }

    final headers = <String, String>{
      "content-type": "application/json",
      "Authorization": "Bearer $token",
    };

    return _client
        .post(
          endpointUri,
          headers: headers,
          body: jsonEncode({
            "query": query,
            "variables": variables ?? const {},
            if (operationName != null) "operationName": operationName,
          }),
        )
        .timeout(timeoutOverride ?? timeout);
  }
}
