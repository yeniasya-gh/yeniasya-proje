import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class HomeBootstrapPayload {
  final List<Map<String, dynamic>> sliders;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> newspapers;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> homeBookEntries;
  final List<Map<String, dynamic>> homeMagazineEntries;

  const HomeBootstrapPayload({
    this.sliders = const [],
    this.magazines = const [],
    this.books = const [],
    this.newspapers = const [],
    this.attachments = const [],
    this.homeBookEntries = const [],
    this.homeMagazineEntries = const [],
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
    );
  }
}

class HomeBootstrapService {
  HomeBootstrapService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? "https://cdn.yeniasyadigital.com",
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const timeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> _getJson(String path) async {
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
    final data = await _getJson("/home/bootstrap");

    return HomeBootstrapPayload.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> fetchSliders() async {
    return _readList(await _getJson("/home/sliders"));
  }

  Future<List<Map<String, dynamic>>> fetchMagazines() async {
    return _readList(await _getJson("/home/magazines"));
  }

  Future<List<Map<String, dynamic>>> fetchBooks() async {
    return _readList(await _getJson("/home/books"));
  }

  Future<List<Map<String, dynamic>>> fetchNewspapers() async {
    return _readList(await _getJson("/home/newspapers"));
  }

  Future<List<Map<String, dynamic>>> fetchAttachments() async {
    return _readList(await _getJson("/home/attachments"));
  }

  Future<List<Map<String, dynamic>>> fetchHomeBookEntries() async {
    return _readList(await _getJson("/home/showcase/books"));
  }

  Future<List<Map<String, dynamic>>> fetchHomeMagazineEntries() async {
    return _readList(await _getJson("/home/showcase/magazines"));
  }
}
