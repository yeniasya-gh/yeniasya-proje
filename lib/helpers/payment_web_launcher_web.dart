// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void launchPaymentHtmlInSameTab(String htmlContent) {
  final blob = html.Blob([htmlContent], "text/html");
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  html.window.location.assign(blobUrl);
}

void launchPaymentUrlInSameTab(String url) {
  html.window.location.assign(url);
}
