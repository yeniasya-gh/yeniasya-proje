import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'logging_service.dart';
import 'auth/auth_token_store.dart';

enum UploadFileType { book, magazine, newspaper, supplement, slider, profile }

class UploadService {
  UploadService({String? baseUrl})
    : _baseUrl = baseUrl ?? "https://cdn.yeniasyadigital.com";

  final LoggingService _logger = LoggingService();
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
      case UploadFileType.supplement:
        return "ek";
      case UploadFileType.slider:
        return "slider";
      case UploadFileType.profile:
        return "profil";
    }
  }

  /// Normalizes a returned path (e.g. `/public/kitap/x.png`) to a fully usable URL.
  static String normalizeUrl(
    String url, {
    String baseUrl = "https://cdn.yeniasyadigital.com",
  }) {
    final value = url.trim();
    if (value.isEmpty) return value;

    if (value.startsWith("data:")) return value;
    if (value.startsWith("assets/")) return value;
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }

    // Defensive: sometimes a URL can be persisted without the leading "h".
    // Example: `ttps://yeniasya.b-cdn.net/...`
    if (value.startsWith("ttps://") || value.startsWith("ttp://")) {
      return "h$value";
    }

    // Protocol-relative URLs: `//example.com/a.png`
    if (value.startsWith("//")) {
      return "https:$value";
    }

    // Host without scheme: `yeniasya.b-cdn.net/...`
    final looksLikeHost = RegExp(
      r"^[a-zA-Z0-9][a-zA-Z0-9.-]*\\.[a-zA-Z]{2,}(/|$)",
    ).hasMatch(value);
    if (looksLikeHost) {
      return "https://$value";
    }

    if (value.startsWith("/")) return "$baseUrl$value";
    return "$baseUrl/$value";
  }

  Future<String> uploadPublic({
    required UploadFileType type,
    required Uint8List bytes,
    required String filename,
  }) async {
    debugPrint("🟦 uploadPublic() çağrıldı");
    debugPrint(" - type: ${_mapType(type)}");
    debugPrint(" - filename: $filename");
    debugPrint(" - byte size: ${bytes.length}");

    _validate(bytes, filename);
    debugPrint("🟩 Dosya validasyonu başarılı");

    final uri = Uri.parse("$_baseUrl/upload/public");
    debugPrint("➡️ İstek URL: $uri");

    final request = http.MultipartRequest("POST", uri)
      ..fields["type"] = _mapType(type)
      ..files.add(_buildFile(bytes, filename));
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    debugPrint("📤 Dosya istek paketine eklendi");
    debugPrint("📬 İstek gönderiliyor...");

    try {
      final streamed = await request.send();
      debugPrint("📥 Yanıt stream alındı (status: ${streamed.statusCode})");

      final resp = await http.Response.fromStream(streamed);

      debugPrint("📩 Tam yanıt alındı:");
      debugPrint(resp.body);

      final url = _parseUrl(resp);
      debugPrint("🟢 Yükleme başarılı → URL: $url");

      return url;
    } catch (e, s) {
      debugPrint("❌ uploadPublic hata:");
      debugPrint(e.toString());
      debugPrint(s.toString());
      await _logError("uploadPublic", e, s, {
        "type": _mapType(type),
        "filename": filename,
        "status": null,
      });
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
      ..files.add(_buildFile(bytes, filename));
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    try {
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      return _parseUrl(resp);
    } catch (e, s) {
      await _logError("uploadPrivateBook", e, s, {
        "type": "kitap",
        "filename": filename,
      });
      rethrow;
    }
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
      ..files.add(_buildFile(bytes, filename));
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    try {
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      return _parseUrl(resp);
    } catch (e, s) {
      await _logError("uploadPrivate", e, s, {
        "type": _mapType(type),
        "filename": filename,
      });
      rethrow;
    }
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
      _logError(
        "parseUrl",
        Exception("Yükleme başarısız (${resp.statusCode})"),
        null,
        {"status": resp.statusCode, "body": resp.body},
      );
      throw Exception("Yükleme başarısız (${resp.statusCode}): ${resp.body}");
    }
    try {
      final data = jsonDecode(resp.body);
      final url = data["url"] ?? data["path"] ?? data["file"];
      if (url == null) throw Exception("Sunucudan URL alınamadı.");
      return url.toString();
    } catch (e) {
      _logError("parseUrl", e, null, {
        "body": resp.body,
        "status": resp.statusCode,
      });
      throw Exception("Sunucu yanıtı çözülemedi: ${resp.body}");
    }
  }

  String _ext(String filename) {
    final dot = filename.lastIndexOf(".");
    if (dot == -1 || dot == filename.length - 1) return "";
    return filename.substring(dot + 1).toLowerCase();
  }

  Future<void> _logError(
    String operation,
    Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
  ) async {
    try {
      await _logger.logError(
        service: "UploadService",
        operation: operation,
        message: error.toString(),
        stackTrace: stackTrace?.toString(),
        payload: payload,
      );
    } catch (_) {
      // ignore: avoid_print
      print("UploadService logging failed");
    }
  }
}
