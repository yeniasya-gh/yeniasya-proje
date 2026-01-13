import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../profile/pdf_viewer_screen.dart';

class InAppWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const InAppWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  InAppWebViewController? _controller;
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
    final controller = _controller;
    if (controller == null) return;
    _loadingViewer = true;
    final viewerUrl = _wrapPdfUrl(pdfUrl);
    debugPrint("🟦 WebView viewer: $viewerUrl");
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(viewerUrl)));
    _loadingViewer = false;
  }

  void _openPdfFallback(String url) {
    if (_openedPdfFallback) return;
    _openedPdfFallback = true;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: url,
          title: widget.title,
          isPrivate: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = WebUri(widget.url);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          if (_progress < 1) LinearProgressIndicator(value: _progress),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: uri),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    useOnDownloadStart: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    supportZoom: true,
                    builtInZoomControls: true,
                    displayZoomControls: false,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStart: (_, url) {
                    debugPrint("🟦 WebView start: ${url?.toString()}");
                    final current = url?.toString() ?? "";
                    if (_isPdfUrl(current)) {
                      _loadPdfViewer(current);
                    }
                  },
                  onLoadStop: (_, url) {
                    debugPrint("🟩 WebView finish: ${url?.toString()}");
                  },
                  onProgressChanged: (_, progress) {
                    if (!mounted) return;
                    setState(() {
                      _progress = progress / 100.0;
                    });
                  },
                  onDownloadStartRequest: (_, request) {
                    final target = request.url.toString();
                    debugPrint("⬇️ WebView download: $target");
                    if (_isPdfUrl(target)) {
                      _loadPdfViewer(target);
                      _openPdfFallback(target);
                    }
                  },
                  shouldInterceptRequest: (_, request) async {
                    debugPrint("🟨 WebView intercept: ${request.url}");
                    return null;
                  },
                  onLoadError: (_, __, ____, message) {
                    if (!mounted) return;
                    debugPrint("🟥 WebView error: $message");
                    setState(() {
                      _errorText = message;
                    });
                  },
                  onLoadHttpError: (_, __, statusCode, description) {
                    if (!mounted) return;
                    debugPrint("🟥 WebView HTTP error: $statusCode $description");
                    setState(() {
                      _errorText = "HTTP $statusCode: $description";
                    });
                  },
                ),
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
