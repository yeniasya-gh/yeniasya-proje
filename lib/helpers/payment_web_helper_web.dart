import 'dart:html' as html;

class PaymentWindowHandle {
  final html.WindowBase? window;
  const PaymentWindowHandle(this.window);
}

PaymentWindowHandle? openPaymentWindow() {
  final win = html.window.open("about:blank", "_blank");
  return PaymentWindowHandle(win);
}

Future<void> loadPaymentHtml(PaymentWindowHandle? handle, String htmlContent) async {
  final blob = html.Blob([htmlContent], "text/html");
  final url = html.Url.createObjectUrlFromBlob(blob);
  final target = handle?.window;
  if (target != null) {
    target.location.href = url;
  } else {
    html.window.location.href = url;
  }
}
