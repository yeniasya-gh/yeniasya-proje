import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logging_service.dart';
import 'upload_service.dart';

/// Basit bir şifreli dosya cache yöneticisi.
/// - Android/iOS: dosyalar AES ile şifreli olarak saklanır, anahtar SecureStorage'da tutulur.
/// - Web: path_provider/secure storage olmadığı için network'ten okur, disk cache kullanılmaz.
class SecureFileService {
  SecureFileService._internal();
  static final SecureFileService instance = SecureFileService._internal();
  final LoggingService _logger = LoggingService();

  static const _keyStorage = FlutterSecureStorage();
  static const _keyName = "secure_file_aes_key";

  Future<Uint8List> getPdfBytes({
    required String url,
    required bool isPrivate,
    ValueChanged<double>? onProgress,
  }) async {
    final normalized = UploadService.normalizeUrl(url);
    final cacheKey = isPrivate ? _extractPath(normalized) : normalized;
    final filename = _safeFileName(cacheKey) + ".enc";

    if (kIsWeb) {
      // Web için disk cache yerine direkt network'ten al.
      return _downloadRaw(
        normalized,
        isPrivate: isPrivate,
        onProgress: onProgress,
      );
    }

    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, filename));

    if (await file.exists()) {
      var cacheValid = false;
      try {
        final encrypted = await file.readAsBytes();
        final decrypted = await _decrypt(encrypted);
        cacheValid = _looksLikePdf(decrypted);
        if (cacheValid) {
          onProgress?.call(1);
          return decrypted;
        }
      } catch (_) {
        // bozuk dosya, silip tekrar indir
      }
      if (!cacheValid) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    final raw = await _downloadRaw(
      normalized,
      isPrivate: isPrivate,
      onProgress: onProgress,
    );
    if (!_looksLikePdf(raw)) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "getPdfBytes",
        message: "Downloaded content is not a PDF",
        payload: {
          "url": normalized,
          "isPrivate": isPrivate,
          "bytes": raw.length,
          "head": _previewBytes(raw),
          "platform": defaultTargetPlatform.toString(),
        },
      );
      throw Exception("PDF içeriği alınamadı.");
    }
    try {
      final encrypted = await _encrypt(raw);
      await file.writeAsBytes(encrypted, flush: true);
    } catch (e, s) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "cacheEncrypt",
        message: e.toString(),
        stackTrace: s.toString(),
        payload: {
          "url": normalized,
          "isPrivate": isPrivate,
          "bytes": raw.length,
          "os": Platform.operatingSystem,
          "osVersion": Platform.operatingSystemVersion,
          "platform": defaultTargetPlatform.toString(),
        },
      );
      // Retry once after resetting stored key (Android keystore can invalidate).
      try {
        await _resetStoredKey();
        final encrypted = await _encrypt(raw);
        await file.writeAsBytes(encrypted, flush: true);
      } catch (e2, s2) {
        await _logger.logError(
          service: "SecureFileService",
          operation: "cacheEncryptRetry",
          message: e2.toString(),
          stackTrace: s2.toString(),
          payload: {
            "url": normalized,
            "isPrivate": isPrivate,
            "bytes": raw.length,
            "os": Platform.operatingSystem,
            "osVersion": Platform.operatingSystemVersion,
            "platform": defaultTargetPlatform.toString(),
          },
        );
        // Don't fail viewing the PDF. Skip encrypted cache and just return raw bytes.
      }
    }
    return raw;
  }

  Future<Uint8List> _downloadRaw(
    String url, {
    required bool isPrivate,
    ValueChanged<double>? onProgress,
  }) async {
    final normalized = UploadService.normalizeUrl(url);
    if (!isPrivate) {
      final req = http.Request("GET", Uri.parse(normalized))
        ..headers["accept"] = "application/pdf";
      final resp = await _sendAndCollect(
        req,
        connectTimeout: const Duration(seconds: 10),
        inactivityTimeout: const Duration(seconds: 10),
        overallTimeout: const Duration(minutes: 2),
        onProgress: onProgress,
      );
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        throw Exception("PDF alınamadı (${resp.statusCode})");
      }
      return resp.bodyBytes;
    }

    final path = _extractPath(normalized);

    if (kIsWeb) {
      return _downloadViaViewToken(path, onProgress: onProgress);
    }

    final uri = Uri.parse(UploadService.normalizeUrl("/private/view"));
    final payload = {"path": path};
    _CollectedResponse resp;
    try {
      final req = http.Request("POST", uri)
        ..headers.addAll({
          "content-type": "application/json",
          "accept": "application/pdf",
          "x-api-key": UploadService.privateAuthToken,
        })
        ..body = jsonEncode(payload);
      resp = await _sendAndCollect(
        req,
        connectTimeout: const Duration(seconds: 10),
        inactivityTimeout: const Duration(seconds: 10),
        overallTimeout: const Duration(minutes: 3),
        onProgress: onProgress,
      );
    } on TimeoutException catch (e, s) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "privateViewPost",
        message: e.toString(),
        stackTrace: s.toString(),
        payload: {
          "url": normalized,
          "path": path,
          "platform": defaultTargetPlatform.toString(),
        },
      );
      return _downloadViaViewToken(path, onProgress: onProgress);
    } catch (e, s) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "privateViewPost",
        message: e.toString(),
        stackTrace: s.toString(),
        payload: {
          "url": normalized,
          "path": path,
          "platform": defaultTargetPlatform.toString(),
        },
      );
      rethrow;
    }

    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "privateViewPost",
        message: "HTTP ${resp.statusCode}",
        payload: {
          "url": normalized,
          "path": path,
          "status": resp.statusCode,
          "contentType": resp.headers["content-type"],
          "bytes": resp.bodyBytes.length,
          "head": _previewBytes(resp.bodyBytes),
          "platform": defaultTargetPlatform.toString(),
        },
      );
      return _downloadViaViewToken(path, onProgress: onProgress);
    }

    // Some environments return a JSON payload with a signed/direct URL instead
    // of streaming the PDF bytes.
    if (!_looksLikePdf(resp.bodyBytes)) {
      final extracted = _extractUrlFromJson(resp.bodyBytes);
      if (extracted != null && extracted.isNotEmpty) {
        final req = http.Request("GET", Uri.parse(extracted))
          ..headers["accept"] = "application/pdf";
        final redirected = await _sendAndCollect(
          req,
          connectTimeout: const Duration(seconds: 10),
          inactivityTimeout: const Duration(seconds: 10),
          overallTimeout: const Duration(minutes: 2),
          onProgress: onProgress,
        );
        if (redirected.statusCode == 200 &&
            redirected.bodyBytes.isNotEmpty &&
            _looksLikePdf(redirected.bodyBytes)) {
          return redirected.bodyBytes;
        }
        await _logger.logError(
          service: "SecureFileService",
          operation: "privateViewJsonUrl",
          message: "Non-PDF response from extracted URL",
          payload: {
            "url": normalized,
            "path": path,
            "extractedUrlHost": Uri.tryParse(extracted)?.host,
            "status": redirected.statusCode,
            "contentType": redirected.headers["content-type"],
            "bytes": redirected.bodyBytes.length,
            "head": _previewBytes(redirected.bodyBytes),
            "platform": defaultTargetPlatform.toString(),
          },
        );
      }
    }

    if (_looksLikePdf(resp.bodyBytes)) {
      return resp.bodyBytes;
    }

    await _logger.logError(
      service: "SecureFileService",
      operation: "privateViewPost",
      message: "Non-PDF response, falling back to token flow",
      payload: {
        "url": normalized,
        "path": path,
        "status": resp.statusCode,
        "contentType": resp.headers["content-type"],
        "bytes": resp.bodyBytes.length,
        "head": _previewBytes(resp.bodyBytes),
        "platform": defaultTargetPlatform.toString(),
      },
    );
    return _downloadViaViewToken(path, onProgress: onProgress);
  }

  bool _looksLikePdf(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final maxScan = min(bytes.length, 1024);
    for (var i = 0; i < maxScan - 4; i++) {
      final b = bytes[i];
      if (b == 0x25 /* % */ &&
          bytes[i + 1] == 0x50 /* P */ &&
          bytes[i + 2] == 0x44 /* D */ &&
          bytes[i + 3] == 0x46 /* F */ &&
          bytes[i + 4] == 0x2D /* - */ ) {
        return true;
      }
      if (b > 0x20) break;
    }
    return false;
  }

  String _previewBytes(Uint8List bytes) {
    if (bytes.isEmpty) return "";
    final take = min(bytes.length, 200);
    final head = bytes.sublist(0, take);
    try {
      return utf8.decode(head, allowMalformed: true);
    } catch (_) {
      return base64Encode(head);
    }
  }

  Future<Uint8List> _downloadViaViewToken(
    String path, {
    ValueChanged<double>? onProgress,
  }) async {
    final viewToken = await _requestViewToken(path);
    try {
      return await _fetchPdfWithToken(viewToken, onProgress: onProgress);
    } on _TokenExpiredException {
      final refreshed = await _requestViewToken(path);
      return _fetchPdfWithToken(refreshed, onProgress: onProgress);
    }
  }

  Future<_ViewTokenData> _requestViewToken(String path) async {
    final uri = Uri.parse(UploadService.normalizeUrl("/private/view-token"));
    const maxTimeoutRetries = 2;
    http.Response? resp;
    for (var attempt = 0; attempt <= maxTimeoutRetries; attempt++) {
      try {
        resp = await http
            .post(
              uri,
              headers: {
                "content-type": "application/json",
                "accept": "application/json",
                "x-api-key": UploadService.privateAuthToken,
              },
              body: jsonEncode({"path": path}),
            )
            .timeout(const Duration(seconds: 10));
        break;
      } on TimeoutException catch (e, s) {
        if (attempt >= maxTimeoutRetries) rethrow;
        await _logger.logError(
          service: "SecureFileService",
          operation: "viewTokenRetry",
          message: e.toString(),
          stackTrace: s.toString(),
          payload: {
            "attempt": attempt + 1,
            "path": path,
            "platform": defaultTargetPlatform.toString(),
          },
        );
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    if (resp == null) {
      throw Exception("Token alınamadı (timeout)");
    }

    if (resp.statusCode != 200 || resp.body.isEmpty) {
      throw Exception("Token alınamadı (${resp.statusCode})");
    }

    try {
      final data = jsonDecode(resp.body);
      final tokenUrl = data["url"] ?? data["viewUrl"] ?? data["path"];
      final token = data["token"]?.toString();
      if ((tokenUrl == null || tokenUrl.toString().isEmpty) &&
          (token == null || token.isEmpty)) {
        throw Exception("Token veya URL boş döndü");
      }
      return _ViewTokenData(token: token, url: tokenUrl?.toString());
    } catch (e) {
      throw Exception("Token yanıtı çözülemedi: $e");
    }
  }

  Future<Uint8List> _fetchPdfWithToken(
    _ViewTokenData tokenData, {
    ValueChanged<double>? onProgress,
  }) async {
    final secureUrl = _buildSecureUrl(tokenData);
    final req = http.Request("GET", Uri.parse(secureUrl))
      ..headers["accept"] = "application/pdf";
    final resp = await _sendAndCollect(
      req,
      connectTimeout: const Duration(seconds: 10),
      inactivityTimeout: const Duration(seconds: 10),
      overallTimeout: const Duration(minutes: 3),
      onProgress: onProgress,
    );

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw _TokenExpiredException();
    }

    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw Exception("PDF alınamadı (${resp.statusCode})");
    }

    if (!_looksLikePdf(resp.bodyBytes)) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "fetchPdfWithToken",
        message: "Non-PDF response",
        payload: {
          "secureUrlHost": Uri.tryParse(secureUrl)?.host,
          "status": resp.statusCode,
          "contentType": resp.headers["content-type"],
          "bytes": resp.bodyBytes.length,
          "head": _previewBytes(resp.bodyBytes),
          "platform": defaultTargetPlatform.toString(),
        },
      );
      throw Exception("PDF içeriği alınamadı.");
    }

    return resp.bodyBytes;
  }

  Future<_CollectedResponse> _sendAndCollect(
    http.BaseRequest request, {
    required Duration connectTimeout,
    required Duration inactivityTimeout,
    required Duration overallTimeout,
    ValueChanged<double>? onProgress,
  }) async {
    const maxTimeoutRetries = 2;
    const maxSocketRetries = 1;
    const maxRetries = maxTimeoutRetries;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final client = http.Client();
      try {
        if (attempt > 0) onProgress?.call(0);
        return await (() async {
          final cloned = _cloneRequest(request);
          final streamed = await client.send(cloned).timeout(connectTimeout);
          final total = streamed.contentLength;
          var received = 0;
          final buffer = BytesBuilder(copy: false);
          onProgress?.call(0);
          await for (final chunk in streamed.stream.timeout(
            inactivityTimeout,
          )) {
            buffer.add(chunk);
            received += chunk.length;
            if (onProgress != null && total != null && total > 0) {
              onProgress(received / total);
            }
          }
          onProgress?.call(1);
          return _CollectedResponse(
            statusCode: streamed.statusCode,
            headers: streamed.headers,
            bodyBytes: buffer.takeBytes(),
          );
        })().timeout(overallTimeout);
      } on TimeoutException catch (e, s) {
        final dur = e.duration;
        final isShortTimeout =
            dur == null || dur <= const Duration(seconds: 10);
        if (!isShortTimeout) rethrow;
        if (attempt >= maxTimeoutRetries) rethrow;
        await _logger.logError(
          service: "SecureFileService",
          operation: "downloadRetry",
          message: e.toString(),
          stackTrace: s.toString(),
          payload: {
            "attempt": attempt + 1,
            "method": request.method,
            "url": request.url.toString(),
            "platform": defaultTargetPlatform.toString(),
          },
        );
        await Future<void>.delayed(Duration(milliseconds: 450 * (attempt + 1)));
      } on SocketException catch (e, s) {
        if (attempt >= maxSocketRetries) rethrow;
        await _logger.logError(
          service: "SecureFileService",
          operation: "downloadRetry",
          message: e.toString(),
          stackTrace: s.toString(),
          payload: {
            "attempt": attempt + 1,
            "method": request.method,
            "url": request.url.toString(),
            "platform": defaultTargetPlatform.toString(),
          },
        );
        await Future<void>.delayed(Duration(milliseconds: 450 * (attempt + 1)));
      } finally {
        client.close();
      }
    }

    throw Exception("Download failed after retry");
  }

  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final cloned = http.Request(request.method, request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..headers.addAll(request.headers)
        ..encoding = request.encoding
        ..bodyBytes = request.bodyBytes;
      return cloned;
    }
    throw StateError(
      "Unsupported request type for retry: ${request.runtimeType}",
    );
  }

  Future<String> getWebViewSecureUrl({required String url}) async {
    final normalized = UploadService.normalizeUrl(url);
    final path = _extractPath(normalized);
    final token = await _requestViewToken(path);
    return _buildSecureUrl(token);
  }

  String _buildSecureUrl(_ViewTokenData tokenData) {
    if (tokenData.url != null && tokenData.url!.isNotEmpty) {
      return UploadService.normalizeUrl(tokenData.url!);
    }
    final token = tokenData.token;
    if (token == null || token.isEmpty) {
      throw Exception("Token bulunamadı");
    }
    final base = UploadService.normalizeUrl("/private/view-secure");
    return Uri.parse(
      base,
    ).replace(queryParameters: {"token": token}).toString();
  }

  String _extractPath(String url) {
    final parsed = Uri.tryParse(url);
    final rawPath = (parsed != null && parsed.hasAuthority)
        ? parsed.path
        : url.replaceFirst(RegExp(r'^https?://[^/]+'), "");

    // New CDN format can come as: `/<type>/private/<filename>`
    // Backend endpoints expect: `/private/<type>/<filename>`
    final mapped = RegExp(
      r"^/(kitap|dergi|gazete|ek|slider)/private/(.+)$",
      caseSensitive: false,
    ).firstMatch(rawPath);
    if (mapped != null) {
      final type = mapped.group(1)!.toLowerCase();
      final file = mapped.group(2)!;
      return "/private/$type/$file";
    }

    return rawPath;
  }

  String? _extractUrlFromJson(Uint8List bytes) {
    final text = _previewBytes(bytes).trimLeft();
    if (!(text.startsWith("{") || text.startsWith("["))) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (decoded is Map<String, dynamic>) {
        final url =
            decoded["url"] ??
            decoded["viewUrl"] ??
            decoded["path"] ??
            decoded["file"];
        final value = url?.toString();
        if (value == null || value.isEmpty) return null;
        return UploadService.normalizeUrl(value);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Uint8List> _encrypt(Uint8List data) async {
    final key = await _getOrCreateKey();
    final iv = _randomBytes(16);
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.cbc),
    );
    final encrypted = encrypter
        .encryptBytes(data, iv: enc.IV(Uint8List.fromList(iv)))
        .bytes;
    return Uint8List.fromList(iv + encrypted); // IV + data
  }

  Future<Uint8List> _decrypt(Uint8List data) async {
    if (data.length < 16) return Uint8List(0);
    final key = await _getOrCreateKey();
    final iv = data.sublist(0, 16);
    final cipher = data.sublist(16);
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.cbc),
    );
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(cipher),
      iv: enc.IV(Uint8List.fromList(iv)),
    );
    return Uint8List.fromList(decrypted);
  }

  Future<List<int>> _getOrCreateKey() async {
    String? existing;
    try {
      existing = await _keyStorage.read(key: _keyName);
    } on PlatformException catch (e, s) {
      // Android keystore might invalidate and make previously stored value undecryptable.
      await _logger.logError(
        service: "SecureFileService",
        operation: "keyRead",
        message: e.toString(),
        stackTrace: s.toString(),
        payload: {
          "os": Platform.operatingSystem,
          "osVersion": Platform.operatingSystemVersion,
          "platform": defaultTargetPlatform.toString(),
        },
      );
      await _resetStoredKey();
      existing = null;
    } catch (e, s) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "keyRead",
        message: e.toString(),
        stackTrace: s.toString(),
        payload: {
          "os": Platform.operatingSystem,
          "osVersion": Platform.operatingSystemVersion,
          "platform": defaultTargetPlatform.toString(),
        },
      );
      await _resetStoredKey();
      existing = null;
    }

    if (existing != null && existing.isNotEmpty) {
      try {
        return base64Decode(existing);
      } catch (e, s) {
        await _logger.logError(
          service: "SecureFileService",
          operation: "keyDecode",
          message: e.toString(),
          stackTrace: s.toString(),
          payload: {
            "os": Platform.operatingSystem,
            "osVersion": Platform.operatingSystemVersion,
            "platform": defaultTargetPlatform.toString(),
          },
        );
        await _resetStoredKey();
      }
    }
    final key = _randomBytes(32);
    try {
      await _keyStorage.write(key: _keyName, value: base64Encode(key));
    } on PlatformException catch (e, s) {
      await _logger.logError(
        service: "SecureFileService",
        operation: "keyWrite",
        message: e.toString(),
        stackTrace: s.toString(),
        payload: {
          "os": Platform.operatingSystem,
          "osVersion": Platform.operatingSystemVersion,
          "platform": defaultTargetPlatform.toString(),
        },
      );
      rethrow;
    }
    return key;
  }

  Future<void> _resetStoredKey() async {
    try {
      await _keyStorage.delete(key: _keyName);
    } catch (_) {
      // ignore
    }
  }

  List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }

  Future<bool> hasCached(String url) async {
    if (kIsWeb) return false;
    final dir = await getApplicationSupportDirectory();
    final normalized = UploadService.normalizeUrl(url);
    final cacheKey = _extractPath(normalized);
    final filename = _safeFileName(cacheKey) + ".enc";
    return File(p.join(dir.path, filename)).exists();
  }

  String _safeFileName(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.pathSegments.join("_") ?? url;
    return path.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), "_");
  }
}

class _TokenExpiredException implements Exception {}

class _CollectedResponse {
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bodyBytes;

  _CollectedResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });
}

class _ViewTokenData {
  final String? token;
  final String? url;

  _ViewTokenData({this.token, this.url});
}
