import "dart:async";

import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";

import "../profile/pdf_viewer_screen.dart";

class InAppWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const InAppWebViewScreen({super.key, required this.url, required this.title});

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  String? _errorText;
  bool _loadingViewer = false;
  bool _openedPdfFallback = false;

  bool _isPdfUrl(String url) => url.toLowerCase().contains(".pdf");

  bool _isGview(String url) => url.contains("docs.google.com/gview");

  String _wrapPdfUrl(String url) {
    final encoded = Uri.encodeComponent(url);
    return "https://docs.google.com/gview?embedded=1&url=$encoded";
  }

  Future<void> _loadPdfViewer(String pdfUrl) async {
    if (_loadingViewer || _isGview(pdfUrl)) return;
    _loadingViewer = true;
    final viewerUrl = _wrapPdfUrl(pdfUrl);
    debugPrint("🟦 WebView viewer: $viewerUrl");
    await _controller.loadRequest(Uri.parse(viewerUrl));
    _loadingViewer = false;
  }

  void _openPdfFallback(String url) {
    if (_openedPdfFallback) return;
    _openedPdfFallback = true;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfViewerScreen(url: url, title: widget.title, isPrivate: false),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final target = request.url;
            if (_isPdfUrl(target) && !_isGview(target)) {
              unawaited(_loadPdfViewer(target));
              _openPdfFallback(target);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            debugPrint("🟦 WebView start: $url");
          },
          onPageFinished: (url) {
            debugPrint("🟩 WebView finish: $url");
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            final message = error.description;
            debugPrint("🟥 WebView error: $message");
            setState(() {
              _errorText = message;
            });
          },
          onHttpError: (error) {
            if (!mounted) return;
            final message = "HTTP ${error.response?.statusCode ?? "-"}";
            debugPrint("🟥 WebView HTTP error: $message");
            setState(() {
              _errorText = message;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (_progress < 1) LinearProgressIndicator(value: _progress),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_errorText != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Sayfa yüklenemedi: $_errorText",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
