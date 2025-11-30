import 'dart:convert';
import 'package:http/http.dart' as http;
import 'error/error_manager.dart';
import 'loading_manager.dart';

class HasuraManager {
  HasuraManager._internal();
  static final HasuraManager instance = HasuraManager._internal();

  static const String _endpoint = "https://key-kodiak-32.hasura.app/v1/graphql";
  static const String _adminSecret = "AIY6x8zVY8NIKKD32hrGYFDCLFDUoa41287ImYp7BrLufiReDuVnQ4UWP6GamGvt";

  final http.Client _client = http.Client();

Future<Map<String, dynamic>> graphQLRequest({
  required String query,
  Map<String, dynamic>? variables,
}) async {
    LoadingManager.instance.show(); 
  try {
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        "content-type": "application/json",
        "x-hasura-admin-secret": _adminSecret,
      },
      body: jsonEncode({
        "query": query,
        "variables": variables ?? {},
      }),
    );

    print("🟡 [Hasura] HTTP ${response.statusCode}");
    print("🟡 [Hasura] RAW RESPONSE REQUEST: ${jsonEncode({
        "query": query,
        "variables": variables ?? {},
      })}");
    print("🟡 [Hasura] RAW RESPONSE BODY: ${response.body}");

    if (response.statusCode != 200) {
      print("🔴 [Hasura] NON-200 RESPONSE: ${response.statusCode}");
      print("🔴 [Hasura] BODY: ${response.body}");
      throw Exception("HTTP ${response.statusCode}");
    }

    final Map<String, dynamic> json = jsonDecode(response.body);

    if (json["errors"] != null) {
      // Log full error payload for debugging
      print("🔴 [Hasura] ERROR JSON: ${jsonEncode(json["errors"])}");

      final firstError = (json["errors"] as List).isNotEmpty ? json["errors"][0] : null;
      if (firstError != null) {
        print("🔴 [Hasura] ERROR MESSAGE: ${firstError["message"]}");
        if (firstError["extensions"] != null) {
          print("🔴 [Hasura] ERROR EXTENSIONS: ${jsonEncode(firstError["extensions"])}");
        }
        if (firstError["path"] != null) {
          print("🔴 [Hasura] ERROR PATH: ${firstError["path"]}");
        }
      }
    }

    if (json["errors"] != null) {
      final rawMessage = (json["errors"] as List).isNotEmpty
          ? json["errors"][0]["message"]
          : "Bilinmeyen Hasura hatası";
      final parsed = ErrorManager.parseGraphQLError(rawMessage);
      throw Exception(parsed);
    }

    return json["data"];
  } catch (e) {
    print("🔴 [Hasura] ORIGINAL EXCEPTION: $e");
    print("🔴 [Hasura] CATCH ERROR: $e");

    final parsed = ErrorManager.parseGraphQLError(e.toString());

    print("🔴 [Hasura] FINAL PARSED ERROR: $parsed");
    throw Exception(parsed);
  } finally {
    LoadingManager.instance.hide();
  }
}
}