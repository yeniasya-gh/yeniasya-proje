import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'error/error_manager.dart';
import 'loading_manager.dart';
import 'logging_service.dart';
import 'auth/auth_token_store.dart';

class HasuraManager {
  HasuraManager._internal();
  static final HasuraManager instance = HasuraManager._internal();
  final LoggingService _logger = LoggingService();

  static const String _endpoint = "https://key-kodiak-32.hasura.app/v1/graphql";
  static final Uri _endpointUri = Uri.parse(_endpoint);
  static const String _adminSecret =
      "AIY6x8zVY8NIKKD32hrGYFDCLFDUoa41287ImYp7BrLufiReDuVnQ4UWP6GamGvt";
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
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

      final response = await _client.post(
        _endpointUri,
        headers: {
          "content-type": "application/json",
          if (AuthTokenStore.token != null)
            "Authorization": "Bearer ${AuthTokenStore.token}",
          "x-hasura-admin-secret": _adminSecret,
        },
        body: jsonEncode({"query": query, "variables": variables ?? {}}),
      ).timeout(_timeout);

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
    if (_endpointUri.scheme != "https") {
      throw Exception("Hasura endpoint must use https.");
    }
    if (_endpointUri.host != "key-kodiak-32.hasura.app") {
      throw Exception("Hasura endpoint host not allowed.");
    }
  }
}
