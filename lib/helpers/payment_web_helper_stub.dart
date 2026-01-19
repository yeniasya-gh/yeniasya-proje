class PaymentWindowHandle {
  const PaymentWindowHandle();
}

PaymentWindowHandle? openPaymentWindow() {
  return null;
}

Future<void> loadPaymentHtml(PaymentWindowHandle? handle, String htmlContent) async {
  throw UnsupportedError("Web helper is not available on this platform.");
}
