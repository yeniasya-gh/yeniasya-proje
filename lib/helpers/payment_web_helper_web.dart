import 'dart:async';
import 'dart:html' as html;

import '../screen/checkout/payment_webview_screen.dart';

class PaymentWindowHandle {
  final html.WindowBase? window;
  final StreamController<PaymentResult> _resultController = StreamController<PaymentResult>.broadcast();
  Timer? _pollTimer;
  bool _completed = false;

  PaymentWindowHandle(this.window);

  Stream<PaymentResult> get onResult => _resultController.stream;

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkWindowUrl();
    });
  }

  void _checkWindowUrl() {
    if (_completed) return;

    try {
      // Check if window is closed
      if (window == null || (window as html.Window).closed == true) {
        _finishWithResult(const PaymentResult(false, "Ödeme penceresi kapatıldı."));
        return;
      }

      // Try to read the window's location
      final win = window as html.Window;
      String? href;
      try {
        href = win.location.href;
      } catch (e) {
        // Cross-origin access blocked - payment page loaded, keep polling
        return;
      }

      if (href == null || href.isEmpty || href == "about:blank") return;

      // Check for success or error patterns
      if (href.contains("/payment/pay/success") || href.contains("/payment/pay/error")) {
        final result = _parsePaymentResult(href);
        _finishWithResult(result);
      }
    } catch (e) {
      // Cross-origin or other security error - keep polling
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
      isSuccess ? null : (errorMsg ?? responseMsg ?? "Ödeme başarısız."),
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

  void _finishWithResult(PaymentResult result) {
    if (_completed) return;
    _completed = true;
    _pollTimer?.cancel();
    _resultController.add(result);
    _resultController.close();

    // Close the popup window
    try {
      (window as html.Window?)?.close();
    } catch (_) {}
  }

  void dispose() {
    _pollTimer?.cancel();
    if (!_resultController.isClosed) {
      _resultController.close();
    }
    try {
      (window as html.Window?)?.close();
    } catch (_) {}
  }
}

PaymentWindowHandle? openPaymentWindow(String url) {
  final win = html.window.open(url, "_blank", "width=600,height=700,scrollbars=yes");
  if (win == null) {
    return null;
  }
  final handle = PaymentWindowHandle(win);
  handle.startPolling();
  return handle;
}

Future<PaymentResult?> openPaymentWindowAndWait(String url) async {
  final handle = openPaymentWindow(url);
  if (handle == null) {
    return const PaymentResult(false, "Popup penceresi açılamadı. Lütfen popup engelleyiciyi kapatın.");
  }

  try {
    final result = await handle.onResult.first.timeout(
      const Duration(minutes: 5),
      onTimeout: () => const PaymentResult(false, "Ödeme zaman aşımına uğradı."),
    );
    return result;
  } catch (e) {
    handle.dispose();
    return PaymentResult(false, "Ödeme işlemi sırasında hata: $e");
  }
}

// Legacy functions for compatibility
Future<void> loadPaymentHtml(PaymentWindowHandle? handle, String htmlContent) async {
  final blob = html.Blob([htmlContent], "text/html");
  final url = html.Url.createObjectUrlFromBlob(blob);
  final target = handle?.window;
  if (target != null) {
    (target as html.Window).location.href = url;
  } else {
    html.window.location.href = url;
  }
}
