import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'error/error_manager.dart';
import 'loading_manager.dart';
import 'logging_service.dart';
import 'hasura_service.dart';

class HasuraManager {
  HasuraManager._internal();
  static final HasuraManager instance = HasuraManager._internal();
  static const Duration homeTimeout = Duration(seconds: 30);
  final LoggingService _logger = LoggingService();

  final HasuraService _service = HasuraService();

  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    LoadingManager.instance.show();
    var logged = false;
    try {
      _ensureSecureEndpoint();

      if (kDebugMode) {
        // ignore: avoid_print
        print("🟦 Hasura request");
        // ignore: avoid_print
        print("QUERY: ${query.trim()}");
        // ignore: avoid_print
        print("VARS: ${jsonEncode(variables ?? {})}");
      }

      final response = await _service.post(
        query: query,
        variables: variables,
        timeoutOverride: timeout,
      );

      if (kDebugMode) {
        // ignore: avoid_print
        print("🟩 Hasura response (${response.statusCode})");
        // ignore: avoid_print
        print(response.body);
      }

      if (response.statusCode != 200) {
        unawaited(
          _logger.logError(
            service: "HasuraManager",
            operation: "graphQLRequest",
            message: "HTTP ${response.statusCode}",
            stackTrace: null,
            payload: {
              "response": response.body,
            },
          ),
        );
        logged = true;
        throw Exception("HTTP ${response.statusCode}");
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json["errors"] != null) {
        final firstError = (json["errors"] as List).isNotEmpty
            ? json["errors"][0]
            : null;
        final rawMessage = firstError != null
            ? firstError["message"]
            : "Bilinmeyen Hasura hatası";
        final parsed = ErrorManager.parseGraphQLError(rawMessage);
        unawaited(
          _logger.logError(
            service: "HasuraManager",
            operation: "graphQLRequest",
            message: parsed,
            stackTrace: null,
            payload: {
              "response": json,
            },
          ),
        );
        logged = true;
        throw Exception(parsed);
      }

      return json["data"];
    } catch (e, s) {
      if (!logged) {
        unawaited(
          _logger.logError(
            service: "HasuraManager",
            operation: "graphQLRequest",
            message: e.toString(),
            stackTrace: s.toString(),
            payload: const {"note": "Request failed"},
          ),
        );
        logged = true;
      }
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      throw Exception(parsed);
    } finally {
      LoadingManager.instance.hide();
    }
  }

  void _ensureSecureEndpoint() {
    if (HasuraService.endpointUri.scheme != "https") {
      throw Exception("Hasura endpoint must use https.");
    }
    if (HasuraService.endpointUri.host != "cdn.yeniasyadigital.com") {
      throw Exception("Hasura endpoint host not allowed.");
    }
  }
}
