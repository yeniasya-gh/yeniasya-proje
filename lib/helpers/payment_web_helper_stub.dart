import 'dart:async';

import '../screen/checkout/payment_webview_screen.dart';

class PaymentWindowHandle {
  final StreamController<PaymentResult> _resultController = StreamController<PaymentResult>.broadcast();

  PaymentWindowHandle();

  Stream<PaymentResult> get onResult => _resultController.stream;

  void dispose() {
    if (!_resultController.isClosed) {
      _resultController.close();
    }
  }
}

PaymentWindowHandle? openPaymentWindow(String url) {
  return null;
}

Future<PaymentResult?> openPaymentWindowAndWait(String url) async {
  throw UnsupportedError("Web payment helper is not available on this platform.");
}

Future<void> loadPaymentHtml(PaymentWindowHandle? handle, String htmlContent) async {
  throw UnsupportedError("Web helper is not available on this platform.");
}
