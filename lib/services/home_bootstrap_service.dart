import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeBootstrapPayload {
  final List<Map<String, dynamic>> sliders;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> newspapers;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> homeBookEntries;
  final List<Map<String, dynamic>> homeMagazineEntries;
  final List<Map<String, dynamic>> homeEkEntries;

  const HomeBootstrapPayload({
    this.sliders = const [],
    this.magazines = const [],
    this.books = const [],
    this.newspapers = const [],
    this.attachments = const [],
    this.homeBookEntries = const [],
    this.homeMagazineEntries = const [],
    this.homeEkEntries = const [],
  });

  factory HomeBootstrapPayload.fromJson(Map<String, dynamic> json) {
    final data = json["data"] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json["data"] as Map<String, dynamic>)
        : json;

    List<Map<String, dynamic>> readList(String key) {
      return List<Map<String, dynamic>>.from(data[key] ?? const []);
    }

    return HomeBootstrapPayload(
      sliders: readList("sliders"),
      magazines: readList("magazines"),
      books: readList("books"),
      newspapers: readList("newspapers"),
      attachments: readList("attachments"),
      homeBookEntries: readList("homeBookEntries"),
      homeMagazineEntries: readList("homeMagazineEntries"),
      homeEkEntries: readList("homeEkEntries"),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sliders": sliders,
      "magazines": magazines,
      "books": books,
      "newspapers": newspapers,
      "attachments": attachments,
      "homeBookEntries": homeBookEntries,
      "homeMagazineEntries": homeMagazineEntries,
      "homeEkEntries": homeEkEntries,
    };
  }
}

class HomeBootstrapService {
  HomeBootstrapService({String? baseUrl, http.Client? client})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            "CDN_BASE_URL",
            defaultValue: "https://cdn.yeniasyadijital.com",
          ),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const bootstrapTimeout = Duration(seconds: 12);
  static const sectionTimeout = Duration(seconds: 8);
  static const cacheMaxAge = Duration(hours: 24);
  static const _bootstrapCacheKey = "home_bootstrap_cache_v1";
  static const _bootstrapCacheSavedAtKey = "home_bootstrap_cache_saved_at_v1";

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required Duration timeout,
  }) async {
    final uri = Uri.parse("$_baseUrl$path");
    final response = await _client.get(uri).timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("HOME_HTTP_${response.statusCode}");
    }

    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw Exception("HOME_INVALID_PAYLOAD");
    }
    final data = Map<String, dynamic>.from(json);
    if (data["ok"] == false) {
      throw Exception(data["error"]?.toString() ?? "HOME_REQUEST_FAILED");
    }
    return data;
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> json) {
    return List<Map<String, dynamic>>.from(json["data"] ?? const []);
  }

  Future<HomeBootstrapPayload> fetch() async {
    final data = await _getJson("/home/bootstrap", timeout: bootstrapTimeout);
    final payload = HomeBootstrapPayload.fromJson(data);
    unawaited(cachePayload(payload));
    return payload;
  }

  Future<HomeBootstrapPayload?> readCachedPayload({
    Duration maxAge = cacheMaxAge,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bootstrapCacheKey);
      final savedAtRaw = prefs.getString(_bootstrapCacheSavedAtKey);
      if (raw == null || raw.trim().isEmpty) return null;
      if (savedAtRaw != null && savedAtRaw.trim().isNotEmpty) {
        final savedAt = DateTime.tryParse(savedAtRaw)?.toUtc();
        if (savedAt != null &&
            DateTime.now().toUtc().difference(savedAt) > maxAge) {
          return null;
        }
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return HomeBootstrapPayload.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> cachePayload(HomeBootstrapPayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bootstrapCacheKey, jsonEncode(payload.toJson()));
      await prefs.setString(
        _bootstrapCacheSavedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Home cache must not break the app flow.
    }
  }

  Future<List<Map<String, dynamic>>> fetchSliders() async {
    return _readList(await _getJson("/home/sliders", timeout: sectionTimeout));
  }

  Future<List<Map<String, dynamic>>> fetchMagazines() async {
    return _readList(
      await _getJson("/home/magazines", timeout: sectionTimeout),
    );
  }

  Future<List<Map<String, dynamic>>> fetchBooks() async {
    return _readList(await _getJson("/home/books", timeout: sectionTimeout));
  }

  Future<List<Map<String, dynamic>>> fetchNewspapers() async {
    return _readList(
      await _getJson("/home/newspapers", timeout: sectionTimeout),
    );
  }

  Future<List<Map<String, dynamic>>> fetchAttachments() async {
    return _readList(
      await _getJson("/home/attachments", timeout: sectionTimeout),
    );
  }

  Future<List<Map<String, dynamic>>> fetchHomeBookEntries() async {
    return _readList(
      await _getJson("/home/showcase/books", timeout: sectionTimeout),
    );
  }

  Future<List<Map<String, dynamic>>> fetchHomeMagazineEntries() async {
    return _readList(
      await _getJson("/home/showcase/magazines", timeout: sectionTimeout),
    );
  }

  Future<List<Map<String, dynamic>>> fetchHomeEkEntries() async {
    return _readList(
      await _getJson("/home/showcase/attachments", timeout: sectionTimeout),
    );
  }
}
