import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth/auth_token_store.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/payment_service.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final PaymentRedirectPayload payload;
  final Uri redirectUri;
  final String returnUrl;

  const PaymentWebViewScreen({
    super.key,
    required this.payload,
    required this.redirectUri,
    required this.returnUrl,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _completed = false;
  bool _awaitingResult = false;
  Timer? _pollTimer;
  bool _seenRedirectOnce = false;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint("[payment][ios] $message");
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();
    _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          _log("page started: $url");
          _setLoading(true);
        },
        onPageFinished: (url) {
          _log("page finished: $url");
          _setLoading(false);
          if (_isPaymentResultUrl(url)) {
            _awaitingResult = true;
            _processReturnUrl(url);
          }
        },
        onWebResourceError: (error) {
          // Bazı alt kaynaklar (örn. analitik, css) yüklenemese bile işlemi sonlandırma.
          _setLoading(false);
        },
        onNavigationRequest: (request) {
          final url = request.url;
          _log("navigation request: $url");
          if (!_seenRedirectOnce &&
              url.startsWith(widget.redirectUri.toString())) {
            _seenRedirectOnce = true;
            return NavigationDecision.navigate;
          }
          if (_isPaymentReturnPage(url)) {
            _awaitingResult = true;
            _setLoading(true);
            _log("allowing return page navigation: $url");
            return NavigationDecision.navigate;
          }
          if (_isPaymentResultUrl(url)) {
            _awaitingResult = true;
            _setLoading(true);
            _processReturnUrl(url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );

    _loadRedirect();
  }

  void _setLoading(bool value) {
    if (mounted) {
      if (_awaitingResult && !value) return;
      setState(() => _loading = value);
    }
  }

  bool _isPaymentReturnPage(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains("/payment/return")) {
      return true;
    }
    final target = widget.returnUrl;
    return url == target || url.startsWith(target);
  }

  bool _isPaymentResultUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      if (path.contains("/payment/pay/success") ||
          path.contains("/payment/pay/error")) {
        return true;
      }
    }
    final redirect = widget.redirectUri.toString();
    if (_seenRedirectOnce && url.startsWith(redirect)) return true;
    return false;
  }

  Future<void> _processReturnUrl(String url) async {
    if (_completed || !mounted) return;
    _awaitingResult = true;
    _setLoading(true);
    _log("processing return url: $url");
    try {
      final fromUrl = _parseResultFromUrl(url);
      if (fromUrl != null) {
        _log(
          "parsed from url -> approved=${fromUrl["approved"]} responseCode=${fromUrl["responseCode"]} errorCode=${fromUrl["errorCode"]}",
        );
        _finishWithResult(PaymentResult.fromJson(fromUrl));
        return;
      }
      final currentHref = await _readCurrentLocationHref();
      if (currentHref != null && currentHref.isNotEmpty && currentHref != url) {
        _log("current location href: $currentHref");
        final fromCurrentHref = _parseResultFromUrl(currentHref);
        if (fromCurrentHref != null) {
          _log(
            "parsed from current href -> approved=${fromCurrentHref["approved"]} responseCode=${fromCurrentHref["responseCode"]} errorCode=${fromCurrentHref["errorCode"]}",
          );
          _finishWithResult(PaymentResult.fromJson(fromCurrentHref));
          return;
        }
      }

      Map<String, dynamic> data;
      Object? lastError;
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          data = await _readJsonFromPage();
          _log(
            "parsed from page -> approved=${data["approved"]} responseCode=${data["responseCode"]} errorCode=${data["errorCode"]}",
          );
          _finishWithResult(PaymentResult.fromJson(data));
          return;
        } catch (e) {
          lastError = e;
          _log("page parse attempt $attempt failed: $e");
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 350));
          }
        }
      }
      throw lastError ?? Exception("Odeme sonucu okunamadi.");
    } catch (e) {
      _log("failed to read return result: $e");
      _finishWithResult(const PaymentResult(false, "Odeme sonucu alinmadi."));
    }
  }

  Future<Map<String, dynamic>> _readJsonFromPage() async {
    final raw = await _controller.runJavaScriptReturningResult(
      "document.body.innerText",
    );
    String text;
    if (raw is String) {
      text = raw;
    } else {
      text = raw.toString();
    }
    text = text.trim();
    _log("return page body length=${text.length}");
    if (text.startsWith('"') && text.endsWith('"')) {
      final decoded = jsonDecode(text);
      if (decoded is String) {
        text = decoded;
      }
    }
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is String) {
        final inner = jsonDecode(parsed);
        if (inner is Map<String, dynamic>) return inner;
      }
    } catch (_) {
      // fall through to querystring parse
    }
    if (text.contains("=")) {
      final normalized = text.replaceAll("+", " ");
      final parsed = Uri.splitQueryString(normalized);
      return Map<String, dynamic>.from(parsed);
    }
    throw Exception("Odeme sonucu json degil");
  }

  Future<String?> _readCurrentLocationHref() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        "window.location.href",
      );
      final text = raw is String ? raw : raw.toString();
      final trimmed = text.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded;
        }
      }
      return trimmed;
    } catch (e) {
      _log("failed to read current location href: $e");
      return null;
    }
  }

  Map<String, dynamic>? _parseResultFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final qp = uri.queryParameters;
    if (qp.isEmpty) return null;
    final map = Map<String, dynamic>.from(qp);
    // Normalize expected keys
    map["approved"] = qp["approved"] == "true" || qp["responseCode"] == "00";
    map["responseCode"] = qp["responseCode"] ?? qp["code"];
    map["responseMsg"] = qp["responseMsg"] ?? qp["message"];
    map["errorCode"] = qp["errorCode"];
    map["errorMsg"] = qp["errorMsg"];
    map["merchantPaymentId"] = qp["merchantPaymentId"] ?? qp["pgOrderId"];
    return map;
  }

  Future<void> _loadRedirect() async {
    try {
      final payload = widget.payload.toJson();

      final token = AuthTokenStore.token?.trim();
      if (token == null || token.isEmpty) {
        _finishWithResult(
          const PaymentResult(
            false,
            "Oturum süresi dolmuş. Lütfen tekrar giriş yapın.",
          ),
        );
        return;
      }

      final headers = {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      };

      // iOS'ta WKWebView POST navigation güvenilir değildi.
      // Backend aynı HTML/redirect cevabını verdiği için tüm platformlarda
      // önce HTTP POST yapıp ardından dönen HTML'i WebView'e yükliyoruz.
      final resp = await http.post(
        widget.redirectUri,
        headers: headers,
        body: jsonEncode(payload),
      );
      _log(
        "redirect response: status=${resp.statusCode} redirect=${resp.isRedirect} contentType=${resp.headers["content-type"]} bodyLength=${resp.body.length}",
      );
      final location = resp.headers["location"];
      if (resp.isRedirect && location != null) {
        _log("redirect location header: $location");
        _processReturnUrl(location);
        return;
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        String message = "Ödeme işlemi başlatılamadı.";
        try {
          final data = jsonDecode(resp.body);
          if (data is Map<String, dynamic>) {
            final apiMessage =
                data["error"]?.toString().trim() ??
                data["message"]?.toString().trim();
            if (apiMessage != null && apiMessage.isNotEmpty) {
              message = apiMessage;
            }
          }
        } catch (_) {
          final body = resp.body.trim();
          if (body.isNotEmpty) {
            message = body;
          }
        }
        _finishWithResult(PaymentResult(false, message));
        return;
      }
      await _controller.loadHtmlString(
        resp.body,
        baseUrl: widget.redirectUri.origin,
      );
    } catch (e) {
      _log("failed to start payment: $e");
      _finishWithResult(
        const PaymentResult(false, "Ödeme işlemi başlatılamadı."),
      );
    }
  }

  void _finishWithResult(PaymentResult result) {
    if (_completed || !mounted) return;
    _completed = true;
    _awaitingResult = false;
    _pollTimer?.cancel();
    _log(
      "finish result -> success=${result.success} responseCode=${result.responseCode} errorCode=${result.errorCode} message=${result.message}",
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guvenli Odeme"), centerTitle: true),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

class PaymentResult {
  final bool success;
  final String? message;
  final bool? approved;
  final String? merchantPaymentId;
  final String? customerId;
  final String? sessionToken;
  final String? responseCode;
  final String? responseMsg;
  final String? errorCode;
  final String? errorMsg;
  final Map<String, dynamic>? raw;

  const PaymentResult(
    this.success,
    this.message, {
    this.approved,
    this.merchantPaymentId,
    this.customerId,
    this.sessionToken,
    this.responseCode,
    this.responseMsg,
    this.errorCode,
    this.errorMsg,
    this.raw,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final approved =
        json["approved"] == true || json["responseCode"]?.toString() == "00";
    final errorMsg = _decodeMaybe(json["errorMsg"]?.toString());
    final responseMsg = _decodeMaybe(json["responseMsg"]?.toString());
    return PaymentResult(
      approved,
      approved
          ? null
          : resolvePaymentFailureMessage(
              errorMsg: errorMsg,
              responseMsg: responseMsg,
              fallback: "Odeme basarisiz.",
            ),
      approved: json["approved"] == true,
      merchantPaymentId: json["merchantPaymentId"]?.toString(),
      customerId: json["customerId"]?.toString(),
      sessionToken: json["sessionToken"]?.toString(),
      responseCode: json["responseCode"]?.toString(),
      responseMsg: responseMsg,
      errorCode: json["errorCode"]?.toString(),
      errorMsg: errorMsg,
      raw: json["raw"] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json["raw"])
          : null,
    );
  }
}

String resolvePaymentFailureMessage({
  String? errorMsg,
  String? responseMsg,
  String fallback = "Odeme basarisiz.",
}) {
  final explicitError = errorMsg?.trim();
  if (explicitError != null && explicitError.isNotEmpty) {
    return explicitError;
  }

  final normalizedResponse = _normalizePaymentStatusMessage(responseMsg);
  if (normalizedResponse != null && normalizedResponse.isNotEmpty) {
    return normalizedResponse;
  }

  return fallback;
}

String? _decodeMaybe(String? raw) {
  if (raw == null) return null;
  final normalized = raw.replaceAll("+", " ");
  try {
    return Uri.decodeComponent(normalized);
  } catch (_) {
    return normalized;
  }
}

String? _normalizePaymentStatusMessage(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final lower = value.toLowerCase();
  if (lower == "declined" ||
      lower == "cancelled" ||
      lower == "canceled" ||
      lower.contains("user cancelled")) {
    return "İşlem iptal edildi.";
  }

  return value;
}
