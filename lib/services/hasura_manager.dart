import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'error/error_manager.dart';
import 'loading_manager.dart';
import 'logging_service.dart';

class HasuraManager {
  HasuraManager._internal();
  static final HasuraManager instance = HasuraManager._internal();
  final LoggingService _logger = LoggingService();

  static const String _endpoint = "https://key-kodiak-32.hasura.app/v1/graphql";
  static const String _adminSecret =
      "AIY6x8zVY8NIKKD32hrGYFDCLFDUoa41287ImYp7BrLufiReDuVnQ4UWP6GamGvt";

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> graphQLRequest({
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    LoadingManager.instance.show();
    var logged = false;
    try {
      // Request log
      // ignore: avoid_print
      print("🟦 Hasura request");
      // ignore: avoid_print
      print("QUERY: ${query.trim()}");
      // ignore: avoid_print
      print("VARS: ${jsonEncode(variables ?? {})}");

      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          "content-type": "application/json",
          "x-hasura-admin-secret": _adminSecret,
        },
        body: jsonEncode({"query": query, "variables": variables ?? {}}),
      );

      // Response log
      // ignore: avoid_print
      print("🟩 Hasura response (${response.statusCode})");
      // ignore: avoid_print
      print(response.body);

      if (response.statusCode != 200) {
        unawaited(
          _logger.logError(
            service: "HasuraManager",
            operation: "graphQLRequest",
            message: "HTTP ${response.statusCode}",
            stackTrace: null,
            payload: {
              "query": query.trim(),
              "variables": variables,
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
              "query": query.trim(),
              "variables": variables,
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
            payload: {"query": query.trim(), "variables": variables},
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
}
