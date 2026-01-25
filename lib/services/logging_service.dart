import 'dart:convert';

import 'package:http/http.dart' as http;

class LoggingService {
  static const String _endpoint = "https://key-kodiak-32.hasura.app/v1/graphql";
  static const String _adminSecret =
      "AIY6x8zVY8NIKKD32hrGYFDCLFDUoa41287ImYp7BrLufiReDuVnQ4UWP6GamGvt";

  final http.Client _client = http.Client();

  Future<void> logError({
    required String service,
    required String operation,
    required String message,
    String? stackTrace,
    Map<String, dynamic>? payload,
  }) async {
    const mutation = r'''
      mutation LogError($input: app_error_logs_insert_input!) {
        insert_app_error_logs_one(object: $input) { id }
      }
    ''';

    final input = {
      "service": service,
      "operation": operation,
      "message": message,
      "stack_trace": stackTrace,
      if (payload != null) "payload": payload,
    };

    try {
      await _client.post(
        Uri.parse(_endpoint),
        headers: {
          "content-type": "application/json",
          "x-hasura-admin-secret": _adminSecret,
        },
        body: jsonEncode({
          "query": mutation,
          "variables": {"input": input},
        }),
      );
    } catch (_) {
      // Logging must not break app flow.
    }
  }
}
