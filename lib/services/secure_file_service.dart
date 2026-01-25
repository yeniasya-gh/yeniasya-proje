import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  }) async {
    final normalized = UploadService.normalizeUrl(url);
    final filename = _safeFileName(normalized) + ".enc";

    if (kIsWeb) {
      // Web için disk cache yerine direkt network'ten al.
      return _downloadRaw(normalized, isPrivate: isPrivate);
    }

    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, filename));

    if (await file.exists()) {
      var cacheValid = false;
      try {
        final encrypted = await file.readAsBytes();
        final decrypted = await _decrypt(encrypted);
        cacheValid = _looksLikePdf(decrypted);
        if (cacheValid) return decrypted;
      } catch (_) {
        // bozuk dosya, silip tekrar indir
      }
      if (!cacheValid) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    final raw = await _downloadRaw(normalized, isPrivate: isPrivate);
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
    final encrypted = await _encrypt(raw);
    await file.writeAsBytes(encrypted, flush: true);
    return raw;
  }

  Future<Uint8List> _downloadRaw(String url, {required bool isPrivate}) async {
    final normalized = UploadService.normalizeUrl(url);
    if (!isPrivate) {
      final resp = await http
          .get(Uri.parse(normalized), headers: {"accept": "application/pdf"})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        throw Exception("PDF alınamadı (${resp.statusCode})");
      }
      return resp.bodyBytes;
    }

    final path = _extractPath(normalized);

    if (kIsWeb) {
      return _downloadViaViewToken(path);
    }

    final uri = Uri.parse(UploadService.normalizeUrl("/private/view"));
    final payload = {"path": path};
    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              "content-type": "application/json",
              "accept": "application/pdf",
              "x-api-key": UploadService.privateAuthToken,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
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
      return _downloadViaViewToken(path);
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
    return _downloadViaViewToken(path);
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
          bytes[i + 4] == 0x2D /* - */) {
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

  Future<Uint8List> _downloadViaViewToken(String path) async {
    final viewToken = await _requestViewToken(path);
    try {
      return await _fetchPdfWithToken(viewToken);
    } on _TokenExpiredException {
      final refreshed = await _requestViewToken(path);
      return _fetchPdfWithToken(refreshed);
    }
  }

  Future<_ViewTokenData> _requestViewToken(String path) async {
    final uri = Uri.parse(UploadService.normalizeUrl("/private/view-token"));
    final resp = await http
        .post(
          uri,
          headers: {
            "content-type": "application/json",
            "accept": "application/json",
            "x-api-key": UploadService.privateAuthToken,
          },
          body: jsonEncode({"path": path}),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200 || resp.body.isEmpty) {
      throw Exception("Token alınamadı (${resp.statusCode})");
    }

    try {
      final data = jsonDecode(resp.body);
      final tokenUrl = data["url"] ?? data["viewUrl"] ?? data["path"];
      final token = data["token"]?.toString();
      if ((tokenUrl == null || tokenUrl.toString().isEmpty) && (token == null || token.isEmpty)) {
        throw Exception("Token veya URL boş döndü");
      }
      return _ViewTokenData(
        token: token,
        url: tokenUrl?.toString(),
      );
    } catch (e) {
      throw Exception("Token yanıtı çözülemedi: $e");
    }
  }

  Future<Uint8List> _fetchPdfWithToken(_ViewTokenData tokenData) async {
    final secureUrl = _buildSecureUrl(tokenData);
    final resp = await http
        .get(
          Uri.parse(secureUrl),
          headers: {
            "accept": "application/pdf",
          },
        )
        .timeout(const Duration(seconds: 20));

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
    return Uri.parse(base).replace(queryParameters: {"token": token}).toString();
  }

  String _extractPath(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed != null && parsed.hasAuthority) return parsed.path;
    return url.replaceFirst(RegExp(r'^https?://[^/]+'), "");
  }

  Future<Uint8List> _encrypt(Uint8List data) async {
    final key = await _getOrCreateKey();
    final iv = _randomBytes(16);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: enc.IV(Uint8List.fromList(iv))).bytes;
    return Uint8List.fromList(iv + encrypted); // IV + data
  }

  Future<Uint8List> _decrypt(Uint8List data) async {
    if (data.length < 16) return Uint8List(0);
    final key = await _getOrCreateKey();
    final iv = data.sublist(0, 16);
    final cipher = data.sublist(16);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipher), iv: enc.IV(Uint8List.fromList(iv)));
    return Uint8List.fromList(decrypted);
  }

  Future<List<int>> _getOrCreateKey() async {
    final existing = await _keyStorage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }
    final key = _randomBytes(32);
    await _keyStorage.write(key: _keyName, value: base64Encode(key));
    return key;
  }

  List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }

  Future<bool> hasCached(String url) async {
    if (kIsWeb) return false;
    final dir = await getApplicationSupportDirectory();
    final filename = _safeFileName(UploadService.normalizeUrl(url)) + ".enc";
    return File(p.join(dir.path, filename)).exists();
  }

  String _safeFileName(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.pathSegments.join("_") ?? url;
    return path.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), "_");
  }
}

class _TokenExpiredException implements Exception {}

class _ViewTokenData {
  final String? token;
  final String? url;

  _ViewTokenData({this.token, this.url});
}
