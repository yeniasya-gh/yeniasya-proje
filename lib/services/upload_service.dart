import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

enum UploadFileType { book, magazine, newspaper }

class UploadService {
  UploadService({String? baseUrl}) : _baseUrl = baseUrl ?? "https://cdn.yeniasyadigital.com";

  final String _baseUrl;

  // Change here if endpoint/base differs per environment.
  static const String _privateAuthToken = "kPPm8b-12kA-9PxQ-YY822L";
  static String get privateAuthToken => _privateAuthToken;

  static const _allowedMime = {
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "webp": "image/webp",
    "pdf": "application/pdf",
  };

  static const int _maxBytes = 20 * 1024 * 1024; // 20MB

  String _mapType(UploadFileType type) {
    switch (type) {
      case UploadFileType.book:
        return "kitap";
      case UploadFileType.magazine:
        return "dergi";
      case UploadFileType.newspaper:
        return "gazete";
    }
  }

  /// Normalizes a returned path (e.g. `/public/kitap/x.png`) to a fully usable URL.
  static String normalizeUrl(String url, {String baseUrl = "https://cdn.yeniasyadigital.com"}) {
    if (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:")) {
      return url;
    }
    if (url.startsWith("assets/")) return url;
    if (url.startsWith("/")) return "$baseUrl$url";
    return "$baseUrl/$url";
  }

  Future<String> uploadPublic({
    required UploadFileType type,
    required Uint8List bytes,
    required String filename,
  }) async {
  print("🟦 uploadPublic() çağrıldı");
  print(" - type: ${_mapType(type)}");
  print(" - filename: $filename");
  print(" - byte size: ${bytes.length}");

  _validate(bytes, filename);
  print("🟩 Dosya validasyonu başarılı");

  final uri = Uri.parse("$_baseUrl/upload/public");
  print("➡️ İstek URL: $uri");

  final request = http.MultipartRequest("POST", uri)
    ..fields["type"] = _mapType(type)
    ..files.add(_buildFile(bytes, filename));

  print("📤 Dosya istek paketine eklendi");
  print("📬 İstek gönderiliyor...");

  try {
    final streamed = await request.send();
    print("📥 Yanıt stream alındı (status: ${streamed.statusCode})");

    final resp = await http.Response.fromStream(streamed);

    print("📩 Tam yanıt alındı:");
    print(resp.body);

    final url = _parseUrl(resp);
    print("🟢 Yükleme başarılı → URL: $url");

    return url;

  } catch (e, s) {
    print("❌ uploadPublic hata:");
    print(e);
    print(s);
    rethrow;
  }
}

  Future<String> uploadPrivateBook({
    required Uint8List bytes,
    required String filename,
  }) async {
    _validate(bytes, filename);

    final uri = Uri.parse("$_baseUrl/upload/private");
    final request = http.MultipartRequest("POST", uri)
      ..fields["type"] = "kitap"
      ..files.add(_buildFile(bytes, filename))
      ..headers["x-api-key"] = _privateAuthToken;

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return _parseUrl(resp);
  }

  Future<String> uploadPrivate({
    required UploadFileType type,
    required Uint8List bytes,
    required String filename,
  }) async {
    _validate(bytes, filename);

    final uri = Uri.parse("$_baseUrl/upload/private");
    final request = http.MultipartRequest("POST", uri)
      ..fields["type"] = _mapType(type)
      ..files.add(_buildFile(bytes, filename))
      ..headers["x-api-key"] = _privateAuthToken;

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return _parseUrl(resp);
  }

  void _validate(Uint8List bytes, String filename) {
    if (bytes.length > _maxBytes) {
      throw Exception("Dosya 20MB sınırını aşıyor.");
    }
    final ext = _ext(filename);
    if (!_allowedMime.containsKey(ext)) {
      throw Exception("İzin verilmeyen dosya tipi.");
    }
  }

  http.MultipartFile _buildFile(Uint8List bytes, String filename) {
    final ext = _ext(filename);
    final mime = _allowedMime[ext] ?? "application/octet-stream";
    return http.MultipartFile.fromBytes(
      "file",
      bytes,
      filename: filename,
      contentType: MediaType.parse(mime),
    );
  }

  String _parseUrl(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("Yükleme başarısız (${resp.statusCode}): ${resp.body}");
    }
    try {
      final data = jsonDecode(resp.body);
      final url = data["url"] ?? data["path"] ?? data["file"];
      if (url == null) throw Exception("Sunucudan URL alınamadı.");
      return url.toString();
    } catch (e) {
      throw Exception("Sunucu yanıtı çözülemedi: ${resp.body}");
    }
  }

  String _ext(String filename) {
    final dot = filename.lastIndexOf(".");
    if (dot == -1 || dot == filename.length - 1) return "";
    return filename.substring(dot + 1).toLowerCase();
  }
}
