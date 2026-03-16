import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'logging_service.dart';
import 'auth/auth_token_store.dart';

enum UploadFileType { book, magazine, newspaper, supplement, slider, profile }

enum UploadStage { preparing, uploading, processing, completed }

typedef UploadProgressCallback = void Function(UploadProgressSnapshot snapshot);

class UploadProgressSnapshot {
  const UploadProgressSnapshot({
    required this.stage,
    required this.sentBytes,
    required this.totalBytes,
    required this.filename,
  });

  final UploadStage stage;
  final int sentBytes;
  final int totalBytes;
  final String filename;

  double? get fraction {
    if (totalBytes <= 0) return null;
    final value = sentBytes / totalBytes;
    if (value.isNaN || value.isInfinite) return null;
    return value.clamp(0, 1).toDouble();
  }
}

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {this.onBytesSent});

  final void Function(int sentBytes, int totalBytes)? onBytesSent;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final totalBytes = contentLength;
    var sentBytes = 0;
    onBytesSent?.call(0, totalBytes);
    final stream = byteStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sentBytes += data.length;
          onBytesSent?.call(sentBytes, totalBytes);
          sink.add(data);
        },
      ),
    );
    return http.ByteStream(stream);
  }
}

class UploadService {
  UploadService({String? baseUrl, http.Client? client})
    : _baseUrl = baseUrl ?? "https://cdn.yeniasyadijital.com",
      _client = client ?? http.Client();

  final LoggingService _logger = LoggingService();
  final String _baseUrl;
  final http.Client _client;

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

  static const int maxUploadBytes = 50 * 1024 * 1024; // 50MB
  static const Duration _uploadTimeout = Duration(minutes: 3);
  static const _managedPublicTypes = {
    "kitap",
    "gazete",
    "dergi",
    "ek",
    "slider",
    "profil",
  };
  static const _managedPrivateTypes = {"kitap", "gazete", "dergi", "ek"};

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
    String baseUrl = "https://cdn.yeniasyadijital.com",
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

  static String formatByteSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    const units = ["KB", "MB", "GB"];
    double value = bytes / 1024;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return "${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}";
  }

  Future<String> uploadPublic({
    required UploadFileType type,
    required Uint8List bytes,
    required String filename,
    UploadProgressCallback? onProgress,
  }) async {
    return _upload(
      operation: "uploadPublic",
      scope: "public",
      type: type,
      bytes: bytes,
      filename: filename,
      onProgress: onProgress,
    );
  }

  Future<String> uploadPrivateBook({
    required Uint8List bytes,
    required String filename,
    UploadProgressCallback? onProgress,
  }) async {
    return _upload(
      operation: "uploadPrivateBook",
      scope: "private",
      type: UploadFileType.book,
      bytes: bytes,
      filename: filename,
      onProgress: onProgress,
    );
  }

  Future<String> uploadPrivate({
    required UploadFileType type,
    required Uint8List bytes,
    required String filename,
    UploadProgressCallback? onProgress,
  }) async {
    return _upload(
      operation: "uploadPrivate",
      scope: "private",
      type: type,
      bytes: bytes,
      filename: filename,
      onProgress: onProgress,
    );
  }

  Future<bool> deleteUploadedFile(String url) async {
    final managedPath = _managedStoragePath(url);
    if (managedPath == null) return false;
    return _deleteManagedPath(managedPath);
  }

  Future<void> cleanupReplacedFile({
    String? previousUrl,
    String? nextUrl,
  }) async {
    final previousPath = _managedStoragePath(previousUrl);
    if (previousPath == null) return;

    final nextPath = _managedStoragePath(nextUrl);
    if (previousPath == nextPath) return;

    try {
      await _deleteManagedPath(previousPath);
    } catch (_) {
      // Main edit flow should not fail if stale CDN cleanup fails.
    }
  }

  Future<void> cleanupRemovedFile(String? url) async {
    final managedPath = _managedStoragePath(url);
    if (managedPath == null) return;

    try {
      await _deleteManagedPath(managedPath);
    } catch (_) {
      // Main remove flow should not fail if stale CDN cleanup fails.
    }
  }

  void _validate(Uint8List bytes, String filename) {
    if (bytes.length > maxUploadBytes) {
      throw Exception("Dosya 50MB sınırını aşıyor.");
    }
    final ext = _ext(filename);
    if (!_allowedMime.containsKey(ext)) {
      throw Exception("İzin verilmeyen dosya tipi.");
    }
  }

  Future<String> _upload({
    required String operation,
    required String scope,
    required UploadFileType type,
    required Uint8List bytes,
    required String filename,
    UploadProgressCallback? onProgress,
  }) async {
    debugPrint("🟦 $operation() çağrıldı");
    debugPrint(" - scope: $scope");
    debugPrint(" - type: ${_mapType(type)}");
    debugPrint(" - filename: $filename");
    debugPrint(" - byte size: ${bytes.length}");

    _validate(bytes, filename);

    final uri = Uri.parse("$_baseUrl/upload/$scope");
    final request =
        _ProgressMultipartRequest(
            "POST",
            uri,
            onBytesSent: (sentBytes, totalBytes) {
              onProgress?.call(
                UploadProgressSnapshot(
                  stage: UploadStage.uploading,
                  sentBytes: sentBytes,
                  totalBytes: totalBytes,
                  filename: filename,
                ),
              );
            },
          )
          ..fields["type"] = _mapType(type)
          ..files.add(_buildFile(bytes, filename));
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }

    onProgress?.call(
      UploadProgressSnapshot(
        stage: UploadStage.preparing,
        sentBytes: 0,
        totalBytes: bytes.length,
        filename: filename,
      ),
    );

    try {
      final streamed = await _client.send(request).timeout(_uploadTimeout);
      onProgress?.call(
        UploadProgressSnapshot(
          stage: UploadStage.processing,
          sentBytes: bytes.length,
          totalBytes: bytes.length,
          filename: filename,
        ),
      );
      final resp = await http.Response.fromStream(
        streamed,
      ).timeout(_uploadTimeout);
      final url = _parseUrl(resp);
      onProgress?.call(
        UploadProgressSnapshot(
          stage: UploadStage.completed,
          sentBytes: bytes.length,
          totalBytes: bytes.length,
          filename: filename,
        ),
      );
      return url;
    } on TimeoutException catch (e, s) {
      final error = Exception(
        "Yükleme zaman aşımına uğradı. Lütfen bağlantıyı kontrol edip tekrar deneyin.",
      );
      await _logError(operation, error, s, {
        "type": _mapType(type),
        "filename": filename,
        "scope": scope,
        "reason": e.toString(),
      });
      throw error;
    } catch (e, s) {
      await _logError(operation, e, s, {
        "type": _mapType(type),
        "filename": filename,
        "scope": scope,
      });
      rethrow;
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
      throw Exception(_friendlyServerError(resp));
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

  String _friendlyServerError(http.Response resp) {
    String bodyMessage = "";
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        bodyMessage =
            decoded["error"]?.toString().trim() ??
            decoded["message"]?.toString().trim() ??
            "";
      }
    } catch (_) {
      bodyMessage = resp.body.trim();
    }

    switch (resp.statusCode) {
      case 400:
        return bodyMessage.isNotEmpty
            ? bodyMessage
            : "Yükleme isteği geçersiz.";
      case 401:
        return "Oturum doğrulanamadı. Lütfen admin paneline yeniden giriş yapın.";
      case 413:
        return "Dosya boyutu 50MB sınırını aşıyor.";
      case 429:
        return "Çok fazla yükleme denemesi yapıldı. Lütfen biraz sonra tekrar deneyin.";
      case 500:
      case 502:
      case 503:
      case 504:
        return "CDN yükleme servisi geçici olarak yanıt vermiyor. Lütfen tekrar deneyin.";
      default:
        if (bodyMessage.isNotEmpty) {
          return "Yükleme başarısız (${resp.statusCode}): $bodyMessage";
        }
        return "Yükleme başarısız (${resp.statusCode}).";
    }
  }

  String _ext(String filename) {
    final dot = filename.lastIndexOf(".");
    if (dot == -1 || dot == filename.length - 1) return "";
    return filename.substring(dot + 1).toLowerCase();
  }

  Set<String> _managedHosts() {
    final hosts = <String>{"yeniasya.b-cdn.net", "cdn.yeniasyadijital.com"};
    final parsedBase = Uri.tryParse(_baseUrl);
    final baseHost = parsedBase?.host.trim().toLowerCase() ?? "";
    if (baseHost.isNotEmpty) {
      hosts.add(baseHost);
    }
    return hosts;
  }

  String? _managedStoragePath(String? url) {
    final raw = url?.trim() ?? "";
    if (raw.isEmpty) return null;

    final normalized = normalizeUrl(raw, baseUrl: _baseUrl);
    Uri uri;
    try {
      uri = Uri.parse(normalized);
    } catch (_) {
      return null;
    }

    if (uri.host.isNotEmpty &&
        !_managedHosts().contains(uri.host.toLowerCase())) {
      return null;
    }

    final path = uri.path.replaceAll(RegExp(r"/{2,}"), "/");
    final direct = RegExp(
      r"^/(kitap|gazete|dergi|ek|slider|profil)/(public|private)/([^/]+)$",
      caseSensitive: false,
    ).firstMatch(path);
    final routed = RegExp(
      r"^/(public|private)/(kitap|gazete|dergi|ek|slider|profil)/([^/]+)$",
      caseSensitive: false,
    ).firstMatch(path);
    final privateAlias = RegExp(
      r"^/private/(kitap|gazete|dergi|ek)/([^/]+)$",
      caseSensitive: false,
    ).firstMatch(path);

    String type;
    String scope;
    String filename;

    if (direct != null) {
      type = direct.group(1)!.toLowerCase();
      scope = direct.group(2)!.toLowerCase();
      filename = Uri.decodeComponent(direct.group(3)!);
    } else if (routed != null) {
      scope = routed.group(1)!.toLowerCase();
      type = routed.group(2)!.toLowerCase();
      filename = Uri.decodeComponent(routed.group(3)!);
    } else if (privateAlias != null) {
      scope = "private";
      type = privateAlias.group(1)!.toLowerCase();
      filename = Uri.decodeComponent(privateAlias.group(2)!);
    } else {
      return null;
    }

    final publicAllowed =
        scope == "public" && _managedPublicTypes.contains(type);
    final privateAllowed =
        scope == "private" && _managedPrivateTypes.contains(type);
    if (!publicAllowed && !privateAllowed) return null;
    if (filename.isEmpty || filename.contains("/") || filename.contains("?")) {
      return null;
    }

    return "/$type/$scope/$filename";
  }

  Map<String, String> _authorizedJsonHeaders() {
    final headers = <String, String>{"content-type": "application/json"};
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  Future<bool> _deleteManagedPath(String managedPath) async {
    final uri = Uri.parse("$_baseUrl/upload/delete");

    try {
      final resp = await http.post(
        uri,
        headers: _authorizedJsonHeaders(),
        body: jsonEncode({"path": managedPath}),
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          "CDN delete başarısız (${resp.statusCode}): ${resp.body}",
        );
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data["ok"] != true) {
        throw Exception(data["error"]?.toString() ?? "CDN delete başarısız.");
      }
      return data["deleted"] != false;
    } catch (e, s) {
      await _logError("deleteUploadedFile", e, s, {"path": managedPath});
      rethrow;
    }
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
