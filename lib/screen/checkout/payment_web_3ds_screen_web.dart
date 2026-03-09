// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import 'payment_webview_screen.dart';

class PaymentWeb3dsScreen extends StatefulWidget {
  final String? initialUrl;
  final String? htmlContent;
  final String returnUrl;

  const PaymentWeb3dsScreen({
    super.key,
    this.initialUrl,
    this.htmlContent,
    required this.returnUrl,
  });

  @override
  State<PaymentWeb3dsScreen> createState() => _PaymentWeb3dsScreenState();
}

class _PaymentWeb3dsScreenState extends State<PaymentWeb3dsScreen> {
  late final String _viewType;
  late final html.IFrameElement _iframe;
  Timer? _pollTimer;
  String? _blobUrl;
  bool _completed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _viewType =
        "payment-3ds-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(this)}";
    _iframe = html.IFrameElement()
      ..style.border = "none"
      ..style.width = "100%"
      ..style.height = "100%"
      ..allow = "payment *; fullscreen"
      ..setAttribute("allowfullscreen", "true");

    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _iframe.src = widget.initialUrl!;
    } else if (widget.htmlContent != null && widget.htmlContent!.trim().isNotEmpty) {
      final blob = html.Blob([widget.htmlContent!], "text/html");
      _blobUrl = html.Url.createObjectUrlFromBlob(blob);
      _iframe.src = _blobUrl!;
    } else {
      _iframe.srcdoc = "<html><body>Odeme ekrani yuklenemedi.</body></html>";
    }

    _iframe.onLoad.listen((_) {
      if (mounted) {
        setState(() => _loading = false);
      }
      _checkForResult();
    });

    ui.platformViewRegistry.registerViewFactory(_viewType, (int _) => _iframe);

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkForResult(),
    );
  }

  bool _isReturnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      if (path.contains("/payment/pay/success") ||
          path.contains("/payment/pay/error")) {
        return true;
      }
    }

    final target = widget.returnUrl;
    return url == target || url.startsWith(target);
  }

  void _checkForResult() {
    if (_completed) return;

    try {
      final href = _iframe.contentWindow?.location.toString();
      if (href == null || href.isEmpty || href == "about:blank") return;
      if (_isReturnUrl(href)) {
        final result = _parsePaymentResult(href);
        _finish(result);
      }
    } catch (_) {
      // Cross-origin page is still active. Keep polling until it returns to same-origin.
    }
  }

  PaymentResult _parsePaymentResult(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const PaymentResult(false, "Ödeme sonucu okunamadı.");
    }

    final qp = uri.queryParameters;
    final responseCode = qp["responseCode"] ?? "";
    final responseMsg = _decodeMaybe(qp["responseMsg"]);
    final errorCode = qp["errorCode"];
    final errorMsg = _decodeMaybe(qp["errorMsg"]);
    final merchantPaymentId = qp["merchantPaymentId"] ?? qp["pgOrderId"];

    final isSuccess = responseCode == "00" || qp["approved"] == "true";

    return PaymentResult(
      isSuccess,
      isSuccess
          ? null
          : resolvePaymentFailureMessage(
              errorMsg: errorMsg,
              responseMsg: responseMsg,
              fallback: "Ödeme başarısız.",
            ),
      approved: isSuccess,
      merchantPaymentId: merchantPaymentId,
      responseCode: responseCode,
      responseMsg: responseMsg,
      errorCode: errorCode,
      errorMsg: errorMsg,
    );
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

  void _finish(PaymentResult result) {
    if (_completed) return;
    _completed = true;
    _pollTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<bool> _handleExit() async {
    if (_completed) return true;
    _finish(const PaymentResult(false, "İşlem iptal edildi."));
    return false;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleExit();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "3D Güvenli Ödeme",
            style: TextStyle(color: Colors.black87),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _finish(const PaymentResult(false, "İşlem iptal edildi."));
            },
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: HtmlElementView(viewType: _viewType),
            ),
            if (_loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
