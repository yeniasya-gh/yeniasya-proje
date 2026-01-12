import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/payment_config.dart';
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

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();
    if (!kIsWeb) {
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _setLoading(true);
          },
          onPageFinished: (url) {
            _setLoading(false);
            if (_awaitingResult && _isReturnUrl(url)) {
              _processReturnUrl();
            }
          },
          onWebResourceError: (error) {
            if (!_completed && mounted) {
              _completed = true;
              Navigator.pop(context, const PaymentResult(false, "Odeme sayfasi yuklenemedi."));
            }
          },
          onNavigationRequest: (request) {
            if (_isReturnUrl(request.url)) {
              _awaitingResult = true;
              _setLoading(true);
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    }

    _loadRedirect();
  }

  void _setLoading(bool value) {
    if (mounted) {
      if (_awaitingResult && !value) return;
      setState(() => _loading = value);
    }
  }

  bool _isReturnUrl(String url) {
    final target = widget.returnUrl;
    if (url == target) return true;
    return url.startsWith(target);
  }

  Future<void> _processReturnUrl() async {
    if (_completed || !mounted) return;
    _awaitingResult = true;
    _setLoading(true);
    try {
      final data = await _readJsonFromPage();
      final result = PaymentResult.fromJson(data);
      _completed = true;
      _awaitingResult = false;
      Navigator.pop(context, result);
    } catch (e) {
      _completed = true;
      _awaitingResult = false;
      Navigator.pop(context, const PaymentResult(false, "Odeme sonucu alinmadi."));
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
    final parsed = jsonDecode(text);
    if (parsed is Map<String, dynamic>) return parsed;
    throw Exception("Odeme sonucu json degil");
  }

  Future<void> _loadRedirect() async {
    final payload = widget.payload.toJson();
    // ignore: avoid_print
    print("🟦 PaymentWebViewScreen.loadRedirect -> ${widget.redirectUri}");
    // ignore: avoid_print
    print("🟦 PaymentWebViewScreen payload: ${jsonEncode(payload)}");
    final body = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    await _controller.loadRequest(
      widget.redirectUri,
      method: LoadRequestMethod.post,
      headers: {
        "content-type": "application/json",
        "x-api-key": PaymentConfig.apiKey,
      },
      body: body,
    );
    if (kIsWeb) {
      _setLoading(false);
    }
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
    final errorMsg = json["errorMsg"]?.toString();
    final responseMsg = json["responseMsg"]?.toString();
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
