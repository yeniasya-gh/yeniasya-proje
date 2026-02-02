import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth/auth_token_store.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/payment_config.dart';
import '../../services/payment_service.dart';
import '../../helpers/payment_web_helper.dart';
import '../../services/order_service.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final PaymentRedirectPayload payload;
  final Uri redirectUri;
  final String returnUrl;
  final int? orderId;

  const PaymentWebViewScreen({
    super.key,
    required this.payload,
    required this.redirectUri,
    required this.returnUrl,
    this.orderId,
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
  int _pollAttempts = 0;
  PaymentWindowHandle? _paymentWindow;
  final _orderService = OrderService();
  bool _pollingStarted = false;
  bool _seenRedirectOnce = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();
    _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          _setLoading(true);
        },
        onPageFinished: (url) {
          _setLoading(false);
          if (_isReturnUrl(url)) {
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
          if (!_seenRedirectOnce && url.startsWith(widget.redirectUri.toString())) {
            _seenRedirectOnce = true;
            return NavigationDecision.navigate;
          }
          if (_isReturnUrl(url)) {
            _awaitingResult = true;
            _setLoading(true);
            _processReturnUrl(url);
            return NavigationDecision.navigate;
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

  bool _isReturnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      if (path.contains("/payment/pay/success") || path.contains("/payment/pay/error")) {
        return true;
      }
    }
    final target = widget.returnUrl;
    if (url == target || url.startsWith(target)) return true;
    final redirect = widget.redirectUri.toString();
    if (_seenRedirectOnce && url.startsWith(redirect)) return true;
    return false;
  }

  Future<void> _processReturnUrl(String url) async {
    if (_completed || !mounted) return;
    _awaitingResult = true;
    _setLoading(true);
    try {
      final fromUrl = _parseResultFromUrl(url);
      if (fromUrl != null) {
        _finishWithResult(PaymentResult.fromJson(fromUrl));
        return;
      }
      final data = await _readJsonFromPage();
      _finishWithResult(PaymentResult.fromJson(data));
    } catch (e) {
      _finishWithResult(const PaymentResult(false, "Odeme sonucu alinmadi."));
    }
  }

  Future<Map<String, dynamic>> _readJsonFromPage() async {
    final raw = await _controller.runJavaScriptReturningResult("document.body.innerText");
    String text;
    if (raw is String) {
      text = raw;
    } else {
      text = raw.toString();
    }
    text = text.trim();
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
    final payload = widget.payload.toJson();
    // ignore: avoid_print
    print("🟦 PaymentWebViewScreen.loadRedirect -> ${widget.redirectUri}");
    // ignore: avoid_print
    print("🟦 PaymentWebViewScreen payload: ${jsonEncode(payload)}");
    // Tüm platformlarda aynı: WebView içinde yükle, header düşmesin diye Android'de http.post + loadHtmlString.
    if (kIsWeb || Platform.isAndroid) {
      final headers = {
        "content-type": "application/json",
        "x-api-key": PaymentConfig.apiKey,
        if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
          "Authorization": "Bearer ${AuthTokenStore.token}",
      };
      final resp = await http.post(
        widget.redirectUri,
        headers: headers,
        body: jsonEncode(payload),
      );
      final location = resp.headers["location"];
      if (resp.isRedirect && location != null) {
        _processReturnUrl(location);
        return;
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception("Redirect yüklenemedi (${resp.statusCode})");
      }
      await _controller.loadHtmlString(
        resp.body,
        baseUrl: widget.redirectUri.toString(),
      );
    } else {
      // iOS: doğrudan loadRequest
      final body = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      final headers = {
        "content-type": "application/json",
        "x-api-key": PaymentConfig.apiKey,
        if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
          "Authorization": "Bearer ${AuthTokenStore.token}",
      };
      await _controller.loadRequest(
        widget.redirectUri,
        method: LoadRequestMethod.post,
        headers: headers,
        body: body,
      );
    }
  }

  void _startOrderPolling() {
    if (_completed || _pollingStarted) return;
    if (widget.orderId == null) {
      _setLoading(false);
      return;
    }
    _pollingStarted = true;
    _setLoading(true);
    _pollTimer?.cancel();
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      _pollAttempts++;
      if (_pollAttempts > 90) {
        _finishWithResult(const PaymentResult(false, "Odeme sonucu alinmadi."));
        return;
      }
      try {
        final detail = await _orderService.getOrderDetail(widget.orderId!);
        final status = (detail?["status"] ?? "").toString().toLowerCase();
        if (status == "paid") {
          _finishWithResult(const PaymentResult(true, null));
        }
      } catch (_) {
        // keep polling on transient errors
      }
    });
  }

  void _finishWithResult(PaymentResult result) {
    if (_completed || !mounted) return;
    _completed = true;
    _awaitingResult = false;
    _pollTimer?.cancel();
    _pollingStarted = false;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guvenli Odeme"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
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
    final approved = json["approved"] == true || json["responseCode"]?.toString() == "00";
    final errorMsg = _decodeMaybe(json["errorMsg"]?.toString());
    final responseMsg = _decodeMaybe(json["responseMsg"]?.toString());
    return PaymentResult(
      approved,
      approved ? null : (errorMsg ?? responseMsg ?? "Odeme basarisiz."),
      approved: json["approved"] == true,
      merchantPaymentId: json["merchantPaymentId"]?.toString(),
      customerId: json["customerId"]?.toString(),
      sessionToken: json["sessionToken"]?.toString(),
      responseCode: json["responseCode"]?.toString(),
      responseMsg: responseMsg,
      errorCode: json["errorCode"]?.toString(),
      errorMsg: errorMsg,
      raw: json["raw"] is Map<String, dynamic> ? Map<String, dynamic>.from(json["raw"]) : null,
    );
  }
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
