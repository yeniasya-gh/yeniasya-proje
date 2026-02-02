import 'dart:convert';

import 'hasura_service.dart';

class LoggingService {
  final HasuraService _hasura = HasuraService();

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
      await _hasura.post(
        query: mutation,
        variables: {"input": input},
      );
    } catch (_) {
      // Logging must not break app flow.
    }
  }
}
